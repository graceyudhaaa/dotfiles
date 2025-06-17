if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -g theme_display_git_default_branch yes
set -Ux VIRTUAL_ENV_DISABLE_PROMPT 1
set -g theme_newline_cursor yes

# pyenv init
if command -v pyenv 1>/dev/null 2>&1
  pyenv init - | source
end

starship init fish | source

