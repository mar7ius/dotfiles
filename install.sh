#!/usr/bin/env bash

CHEZMOI_REPO="mar7ius/dotfiles"
LOG_FILE="/tmp/log-test.txt"

OPERATION="installing"
LOG_BOX_INITIALIZED="false"

spin_chars="🕑🕝🕓🕟🕕🕡🕗🕣🕙🕥🕛🕧"
spin_count=0

clean_up() {
  tput cnorm
  tput sgr0
}

get_row() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${ROW#*[}"
}
get_col() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${COL}"
}

spin() {
  printf "\r$(tput sitm) $OPERATION...$(tput ritm) ${spin_chars:spin_count++:1}"
  tput sc
  sleep 0.1
  ((spin_count == ${#spin_chars})) && spin_count=0
  if [ "$LOG_BOX_INITIALIZED" = "true" ]; then
    tput cup $ROW_LOG $COL_LOG
    printf "$(
      tput cd
      tput setaf 4
      tput sitm
    )$(tail -n -5 $LOG_FILE)$(
      tput sgr0
      tput ritm
    )"
    tput rc
  else
    printf "\n\n"
    printf %"$(tput cols)"s | tr " " "-"
    COL_LOG=$(get_col)
    ROW_LOG=$(get_row)
    tput rc
    LOG_BOX_INITIALIZED="true"
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
  LOG_BOX_INITIALIZED="false"
  ROW_LOG=""
  COL_LOG=""
  PROC_ID=""
}

loader() {
  printf "\r 🏗  $(eval ruby -e \'puts \"$OPERATION\".capitalize\') $1...\n"
  cat <<EOF >>$LOG_FILE

------------------
$(eval ruby -e \'puts \"$OPERATION\".capitalize\') $1...

EOF
  echo "proc_id varible: ${PROC_ID}   ---- last process id: ${$!}" >>$LOG_FILE
  # The `while kill -0 $PROC_ID` will check if the process is still running.
  # Then, with the `wait` command, we retrieve the exit status of the previous backgrounded command
  # That exit status will be stored in the `$?` variable, and we can use it to check if the command was successful or not.
  tput civis # Hide cursor
  while kill -0 $PROC_ID >/dev/null 2>&1; do
    spin
  done
  tput cnorm # Show cursor

  wait $PROC_ID

  if [ ${?} -ne 0 ]; then
    endspin "$(tput bold) Error while $OPERATION $1 $(tput sgr0)❌"
    printf "\n$(tput sitm) Check the complete log file at: $LOG_FILE\n Here is the last 10 lines: $(tput ritm)\n\n$(tail -n -10 $LOG_FILE)\n\n"
    exit 1
  else
    endspin " $(tput sitm)--> $1 ${OPERATION%ing}ed ! $(tput sgr0)✅" # OPERATION without the last 'ing' + 'ed' (eg. installing -> installed)
  fi
}

check_for_dependencies() {
  echo "$(tput bold)⚙️  Looking for dependencies...$(tput sgr0)"

  # Checking for Xcode command line tools
  printf "🔎 Checking for Xcode command line tools..."
  if [ ! "$(xcode-select -p)" ]; then
    xcode-select --install >>$LOG_FILE 2>&1 &
    PROC_ID=$!
    loader "XCode Command Line Tools"
  else
    printf "\r $(tput sitm)--> Command Line Developer Tools is installed! ✅$(tput sgr0)\n"
  fi

  # Checking for Homebrew:
  printf "🔎 Checking for Homebrew..."
  if [ ! "$(command -v brew)" ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >>$LOG_FILE 2>&1 &
    PROC_ID=$!
    loader "Homebrew"
    export PATH=/opt/homebrew/bin:$PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>/Users/$USER/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    printf "\r $(tput sitm)--> Homebrew is installed ✅$(tput sgr0)\n"
  fi

  # Checking for chezmoi:
  printf "🔎 Checking for chezmoi..."
  if [ ! "$(command -v chezmoi)" ]; then
    brew install chezmoi >>$LOG_FILE 2>&1 &
    PROC_ID=$!
    loader "Chezmoi"
  else
    printf "\r $(tput sitm)--> Chezmoi is installed ✅$(tput sgr0)\n"
  fi
}

run_chezmoi() {
  echo " "
  echo "$(tput bold)⚙️  Running Chezmoi...$(tput sgr0)"
  # check if local chezmoi folder exists
  if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo " 🏗 No local chezmoi found, cloning from ${CHEZMOI_REPO}..."
    chezmoi init "$CHEZMOI_REPO" >>$LOG_FILE 2>&1 &
    PROC_ID=$! # `$!` store the Process ID of the previous background process
    OPERATION="cloning" loader "Chezmoi"

    # chezmoi init --apply "$CHEZMOI_REPO"
  else
    echo "$(tput sitm) Local chezmoi found, using it...$(tput sgr0)"
    chezmoi init && chezmoi apply -v -n
  fi
}

init() {
  clear
  cat <<EOF
  This script will check or install the following dependencies:
  $(tput bold)
  - XCode Command Line Tools
  - Homebrew
  - Chezmoi
  $(tput sgr0)
  It will also clone the Chezmoi repository in your home directory.
  The log file is located at: $LOG_FILE.

EOF

  read -rp "$(tput bold)Press any key to continue... 🚀$(tput sgr0) (Press Ctrl+C to abort)"

  echo " "
  eval "$(sudo -v -p "$(printf 'Sudo is required to install some dependencies.\nPlease enter your password: ')")"
  echo "" >$LOG_FILE
}

run() {
  init
  check_for_dependencies
  run_chezmoi
  echo "$(
    tput el
    tput cd
    tput bold
    tput setaf 118
  )🎉  Done! $(tput sgr0)"
  exec zsh
}

trap 'clean_up' EXIT
run
