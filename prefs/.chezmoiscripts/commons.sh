#!/usr/bin/env bash

LOG_FILE="/tmp/log-test.txt"

# BREW=("/opt/homebrew/bin/brew")

if ! command -v brew &>/dev/null; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

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
