#!/usr/bin/env bash

set -e

CHEZMOI_REPO="mar7ius/dotfiles"


check_for_dependencies() {
  echo "⚙️  Installing dependencies..."

  # Checking for Xcode command line tools
  echo "🔍 Checking for Xcode command line tools..."
  if [ ! "$(xcode-select -p)" ]; then
    echo "🔨 XCode command line tools not found, installing..."
    xcode-select --install
    sleep 1
    osascript <<EOD
tell application "System Events"
    tell process "Install Command Line Developer Tools"
        keystroke return
        click button "Agree" of window "License Agreement"
    end tell
end tell
EOD
  # Check that installation was successful
  if [ ! "$(xcode-select -p)" ]; then
    echo "❌ XCode command line tools not found, please install manually."
    exit 1
  else
    echo "✅ XCode command line tools is now installed."
  fi

  else
    echo "✅ Command Line Developer Tools are already installed!"
  fi

  # Checking for Homebrew:
  echo "🔍 Checking for Homebrew..."
  if [ ! "$(command -v brew)" ]; then
    echo "🔨 Installing Homebrew ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Check that installation was successful
    if [ ! "$(command -v brew)" ]; then
      echo "❌ Homebrew not found, please install manually."
      exit 1
    else
      echo "✅ Homebrew is now installed."
    fi
  else
    echo "✅ Homebrew already installed"
  fi


  # Checking for chezmoi:
  echo "🔍 Checking for chezmoi..."
  if [ ! "$(command -v chezmoi)" ]; then
    echo "🔨 Installing Chezmoi ..."
    brew update && brew install chezmoi
    # Check that installation was successful
    if [ ! "$(command -v chezmoi)" ]; then
      echo "❌ Chezmoi not found, please install manually."
      exit 1
    else
      echo "✅ Chezmoi is now installed."
    fi
  else
    echo "✅ Chezmoi already installed"
  fi
}

run_chezmoi() {
  echo "⚙️  Running Chezmoi..."
  # check if local chezmoi folder exists
  if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo "🔨 No local chezmoi found, cloning from ${CHEZMOI_REPO}..."
    # chezmoi init --apply "$CHEZMOI_REPO"
  else
    echo "🔨 Local chezmoi found, using it..."
    # chezmoi init && chezmoi apply -v -n
  fi
}

run() {
  check_for_dependencies
  run_chezmoi
}

run
