#!/usr/bin/env bash

LOG_FILE="/tmp/log-test.txt"

# Style:
BOLD=$(tput bold)
ITALIC=$(tput sitm)
UNDERLINE=$(tput smul)
END=$(tput sgr0)

# Colors:
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)

# create a function to prompt for a string
prompt_for() {
  local answer=""
  while [ -z "$answer" ]; do
    read -p "${1}" answer
    if [ -z "$answer" ]; then
      echo "The answer cannot be empty."
    fi
  done
  echo "$answer"
}

prompt_for_password() {
  local answer=""
  while [ -z "$answer" ]; do
    read -sp "${1}" answer
    if [ -z "$answer" ]; then
      echo "The answer cannot be empty."
    fi
  done
  echo "$answer"
}

function section {
  echo ""
  echo $BOLD $MAGENTA "*** $1 ***" $END
  echo ""
}

function action {
  echo $BLUE "⚙️  $1" $END
}

function log {
  echo $ITALIC "$1" $END
}

function success {
  echo $GREEN "✅ $1" $END
}
