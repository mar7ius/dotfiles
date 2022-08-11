#!/bin/sh

echo "Checking for age key..."

if [ ! -f "${HOME}/.age_key" ]; then
    echo "key no found, retrieving..."
    chezmoi execute-template '{{ bitwardenAttachment "key.txt.age" .personal.bw_vault.items.age_key_file_id }}' > "${HOME}/key.txt.age"
    age --decrypt --output "${HOME}/.age_key" "${HOME}/key.txt.age"
    chmod 600 "${HOME}/.age_key"
    rm -f "${HOME}/key.txt.age"
fi

echo "done"
