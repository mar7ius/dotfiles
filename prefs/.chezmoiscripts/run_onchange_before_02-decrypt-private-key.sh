#!/bin/sh

{{ template "source-utils" . }}

section "Setting up age encryption"
action "Checking for age key..."

if [ ! -f "${HOME}/.age_key" ]; then
    log "key no found, retrieving..."
    chezmoi execute-template '{{ bitwardenAttachment "key.txt.age" .personal.bw_vault.items.age_key_file_id }}' > "${HOME}/key.txt.age"
    age --decrypt --output "${HOME}/.age_key" "${HOME}/key.txt.age"
    chmod 600 "${HOME}/.age_key"
    rm -f "${HOME}/key.txt.age"
fi

success "Age is ready"
