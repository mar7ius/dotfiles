#!/usr/bin/env bash

CHEZMOI_REPO="mar7ius/dotfiles"
LOG_FILE="/tmp/log-test.txt"

OPERATION="installing"
LOG_BOX_INITIALIZED="false"

spin_chars="🕑🕝🕓🕟🕕🕡🕗🕣🕙🕥🕛🕧"
spin_count=0

cleanup() {
  LOG_BOX_INITIALIZED="false"
  ROW_LOG=""
  COL_LOG=""
  tput cnorm
  tput sgr0
}

# Loader/Spinner methods :
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
  tput cd              # tput ed (clear below the cursor position) doesn't work on macOS, so use tput cd instead
  printf "\r%s\n" "$@" # Clear the `installing...` line and print the status
  cleanup
}

loader() {
  printf "\r 🏗  $(eval ruby -e \'puts \"$OPERATION\".capitalize\') $1...\n"
  cat <<EOF >>$LOG_FILE

------------------
$(eval ruby -e \'puts \"$OPERATION\".capitalize\') $1...

EOF

  # `$!` refers to the last backgrounded process and `while kill -0 $!` will check if the process is still running.
  # Then, with the `wait` command, we retrieve the exit status of the process
  # That exit status will be stored in the `$?` variable, and we can use it to check if the command was successful or not.
  tput civis # Hide cursor
  while kill -0 $! >/dev/null 2>&1; do
    spin
  done
  tput cnorm # Show cursor

  wait $!

  if [ ${?} -ne 0 ]; then
    endspin "$(tput bold) Error while $OPERATION $1 $(tput sgr0)❌"
    printf "\n$(tput sitm) Check the complete log file at: $LOG_FILE\n Here is the last 10 lines: $(tput ritm)\n\n$(tail -n -10 $LOG_FILE)\n\n"
    exit 1
  else
    endspin " $(tput sitm)--> $1 ${OPERATION%ing}ed ! $(tput sgr0)✅" # OPERATION without the last 'ing' + 'ed' (eg. installing -> installed)
  fi
}

# Dependencies check & install methods :
check_for() {
  printf "🔎 Checking for $1..."
  if ! [[ $2 ]] &>/dev/null; then
    ${3} $1
  else
    printf "\r $(tput sitm)--> $1 is installed! ✅$(tput sgr0)\n"
  fi
}

install_brew() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >>$LOG_FILE 2>&1 &
  loader $1
  export PATH=/opt/homebrew/bin:$PATH
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>/Users/$USER/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

install_chezmoi() {
  brew install chezmoi >>$LOG_FILE 2>&1 &
  loader $1
}

install_bitwarden() {
  brew install bitwarden-cli >>$LOG_FILE 2>&1 &
  loader $1
}

# Downloads and installs the xcode command line tools
# Source: https://github.com/Homebrew/install/blob/master/install.sh#L850
chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

install_xcode_cli_tools() {
  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  /usr/bin/sudo /usr/bin/touch "${clt_placeholder}"

  clt_label_command="/usr/sbin/softwareupdate -l |
                    grep -B 1 -E 'Command Line Tools' |
                    awk -F'*' '/^ *\\*/ {print \$2}' |
                    sed -e 's/^ *Label: //' -e 's/^ *//' |
                    sort -V |
                    tail -n1"
  clt_label="$(chomp "$(/bin/bash -c "${clt_label_command}")")"

  if [[ -n "${clt_label}" ]]; then
    /usr/bin/sudo "/usr/sbin/softwareupdate" "-i" "${clt_label}" >>$LOG_FILE 2>&1 &
    loader $1
    /usr/bin/sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools" >>$LOG_FILE 2>&1
  fi
  /usr/bin/sudo "/bin/rm" "-f" "${clt_placeholder}" >>$LOG_FILE 2>&1
}

check_for_dependencies() {
  printf "\n$(tput bold)⚙️  Looking for dependencies...$(tput sgr0)\n\n"

  check_for "XCode Command Line Tools" "-e '/Library/Developer/CommandLineTools/usr/bin/git'" install_xcode_cli_tools
  check_for "Homebrew" "$(command -v brew)" install_brew
  check_for "Chezmoi" "$(command -v chezmoi)" install_chezmoi
  check_for "Bitwarden" "$(command -v bw)" install_bitwarden
}

unlock_bw() {
  echo " "
  echo "$(tput bold)🔐  Login/Unlock Bitwarden...$(tput sgr0)"
  if bw status | grep "locked" &>/dev/null; then
    export BW_SESSION="$(bw unlock --raw)"
    echo "🔓  Bitwarden Vault is now unlocked."
  elif bw status | grep "unauthenticated" &>/dev/null; then
    export BW_SESSION="$(bw login --raw)"
    echo "🔓  Bitwarden Vault is now unlocked."
  elif [[ -z "${BW_SESSION}" ]]; then
    echo "Unable to login/unlock Bitwarden. Try manualy and restart the script"
    exit 1
  fi
}

run_chezmoi() {
  echo " "
  echo "$(tput bold)⚙️  Running Chezmoi...$(tput sgr0)"
  # check if local chezmoi folder exists
  if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo " 🏗 No local chezmoi found, cloning from ${CHEZMOI_REPO}..."
    chezmoi init "$CHEZMOI_REPO" >>$LOG_FILE 2>&1 &
    OPERATION="cloning" loader "Chezmoi"

    exec chezmoi apply -v -n
  else
    echo "$(tput sitm) Local chezmoi found, using it...$(tput sgr0)"
    exec chezmoi apply -v -n
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
  eval "$(sudo -v -p "$(printf 'Admin password is required to install some dependencies.\nPlease enter your password: ')")"
  echo "" >$LOG_FILE
}

run() {
  init
  check_for_dependencies
  unlock_bw
  run_chezmoi
  echo "$(
    tput el
    tput cd
    tput bold
    tput setaf 118
  )🎉  Done! $(tput sgr0)"
}

trap 'cleanup' EXIT
trap 'sudo kill -9 $! >>$LOG_FILE 2>&1' EXIT

run
