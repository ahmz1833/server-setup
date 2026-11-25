Put admin **public** keys here (`<name>.pub`). Public keys are not secret, but strip
personal comments (emails) from the key line if the repo may become public.
They are referenced from `inventories/*/group_vars/all/main.yml` (`core_users[].ssh_keys`).
