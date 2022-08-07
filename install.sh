#!/usr/bin/env bash

CHEZMOI_REPO="mar7ius/dotfiles"
LOG_FILE="/tmp/log-test.txt"

sp="🕑🕝🕓🕟🕕🕡🕗🕣🕙🕥🕛🕧"
sc=0
operation="installing"
is_initialized="false"

function row {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${ROW#*[}"
}
function col {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${COL}"
}

spin() {
  printf "\r $operation... ${sp:sc++:1}"
  tput sc
  sleep 0.1
  ((sc == ${#sp})) && sc=0
  if [ "$is_initialized" = "true" ]; then
    tput cup $ROW2 $COL2
    tail -n -5 $LOG_FILE
    tput rc
  else
    echo ""
    printf %"$(tput cols)"s | tr " " "-"
    COL2=$(col)
    ROW2=$(row)
    tail -n 1 $LOG_FILE
    tput rc
    is_initialized="true"
  fi
}
endspin() {
  tput rc
  tput el
  tput cd # tput ed (clear below the cursor position) doesn't work on macOS, so use tput cd instead
  printf "\r%s\n" "$@" # Clear the `installing...` line and print the status
  reset_spinner
}

reset_spinner() {
  is_initialized="false"
  ROW2=""
  COL2=""
}

loader() {
  printf "\r 🔨 $(eval ruby -e \'puts \"$operation\".capitalize\') $1 ...\n"

  cat <<EOF >>$LOG_FILE

------------------
$(eval ruby -e \'puts \"$operation\".capitalize\') $1...

EOF

  while kill -0 $PROC_ID > /dev/null 2>&1; do # `kill -0` checks if the process is running
    spin
  done

  # From here, the process is done. We can check the exit status of the process :
  wait $PROC_ID
  # $? stores the exit status of the previous command, by using the `wait` command, we retrieve the exit status of the previous backgrounded command.
  if [ ${?} -ne 0 ]; then
    endspin " Error while $operation $1 ❌"
  else
    endspin " --> $1 ${operation%ing}ed ! ✅" # operation without the last 'ing' + 'ed' (eg. installing -> installed)
  fi
  PROC_ID="" # reset command and args
}

check_for_dependencies() {
  echo "⚙️  Looking for dependencies..."

  # Checking for Xcode command line tools
  printf "🔍 Checking for Xcode command line tools..."
  if [ ! "$(xcode-select -p)" ]; then
    xcode-select --install >>$LOG_FILE 2>&1 &
    PROC_ID=$! # `$!` store the Process ID of the previous background process
    loader "XCode Command Line Tools"
    # Check that installation was successful
    if [ ! "$(xcode-select -p)" ]; then
      echo "❌ XCode command line tools not found, please install manually."
      exit 1
    fi

  else
    printf "\r --> Command Line Developer Tools is installed! ✅\n"
  fi

  # Checking for Homebrew:
  printf "🔍 Checking for Homebrew..."
  if [ ! "$(command -v brew)" ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >>$LOG_FILE 2>&1 &
    PROC_ID=$! # `$!` store the Process ID of the previous background process
    loader "Homebrew"
    export PATH=/opt/homebrew/bin:$PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>/Users/$USER/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Check that installation was successful
    if [ ! "$(command -v brew)" ]; then
      echo "❌ Homebrew not found, please install manually."
      exit 1
    fi
  else
    printf "\r --> Homebrew is installed ✅\n"
  fi

  # Checking for chezmoi:
  printf "🔍 Checking for chezmoi..."
  if [ ! "$(command -v chezmoi)" ]; then
    brew install chezmoi >> $LOG_FILE 2>&1 &
    PROC_ID=$! # `$!` store the Process ID of the previous background process
    loader "Chezmoi"
    # Check that installation was successful
    if [ ! "$(command -v chezmoi)" ]; then
      echo "❌ Chezmoi not found, please install manually."
      exit 1
    fi
  else
    printf "\r --> Chezmoi is installed ✅\n"
  fi
}

run_chezmoi() {
  echo "⚙️  Looking for Chezmoi..."
  # check if local chezmoi folder exists
  if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo " 🔨 No local chezmoi found, cloning from ${CHEZMOI_REPO}..."
    # chezmoi init --apply "$CHEZMOI_REPO"
  else
    echo " 🔨 Local chezmoi found, using it..."
    # chezmoi init && chezmoi apply -v -n
  fi
}

run() {
  clear
  eval "$(sudo -v -p "$(printf 'sudo is required to install some dependencies. \nPlease enter your password: ')")"
  echo "" > $LOG_FILE
  check_for_dependencies
  run_chezmoi
  tput el
  tput cd
  echo "🎉  Done!"
  exec zsh
}

run
