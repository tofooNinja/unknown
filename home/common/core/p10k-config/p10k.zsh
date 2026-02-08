# Minimal Powerlevel10k configuration with purple theme
# Based on the purple color from your logo background

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options.
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # Minimal left prompt - only essential elements
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )

  # Minimal right prompt
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of the last command
    command_execution_time  # duration of the last command (if > 3s)
  )

  # Use nerdfont icons
  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=none

  # Icons go before content
  typeset -g POWERLEVEL9K_ICON_BEFORE_CONTENT=true

  # Single line prompt
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

  # No separators for minimal look
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''

  # No prompt terminators for clean look
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=''

  #################################[ prompt_char: prompt symbol ]################################
  # Purple prompt char - the main visual element
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  # Purple colors for the prompt char
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=97    # bright purple
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196 # red for errors
  # Prompt symbols
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_{LEFT,RIGHT}_WHITESPACE=

  ##################################[ dir: current directory ]##################################
  # Purple background for directory
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=96        # purple background
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=255       # white text
  # Shorten long paths
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=250
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=255
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  # Reasonable max length
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3

  #####################################[ vcs: git status ]######################################
  # Git status colors - lighter purple variations
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=61      # darker purple for clean
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=133  # lighter purple for modified
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=61
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=196 # red for conflicts
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=244

  # White text on purple backgrounds
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=255
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=255
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=255
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=255
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=255

  # Simple branch icon
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  # Simplified git formatter for minimal look
  function my_git_formatter() {
    emulate -L zsh
    if [[ -n $P9K_CONTENT ]]; then
      typeset -g my_git_format=$P9K_CONTENT
      return
    fi

    local clean='%255F'    # white foreground
    local modified='%255F' # white foreground
    local res

    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
      local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
      (( $#branch > 20 )) && branch[11,-11]="…"
      res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}"
    fi

    # Simple status indicators
    (( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+"
    (( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!"
    (( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${modified}?"
    (( VCS_STATUS_COMMITS_AHEAD  )) && res+=" ${clean}↑"
    (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}↓"

    typeset -g my_git_format=$res
  }
  functions -M my_git_formatter 2>/dev/null

  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter()))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)

  ##########################[ status: exit code of the last command ]###########################
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  # Only show status on error
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false
  # Error status with purple background
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=196  # red background for errors
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_BACKGROUND=196
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND=196

  ###################[ command_execution_time: duration of the last command ]###################
  # Purple background for execution time
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=255
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=133  # lighter purple
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'

  # Transient prompt - clean up after command execution
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

  # Instant prompt
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # Disable hot reload for performance
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  # Reload if p10k is already loaded
  (( ! $+functions[p10k] )) || p10k reload
}

# Tell `p10k configure` which file it should overwrite.
typeset -g POWERLEVEL9K_CONFIG_FILE=${${(%):-%x}:a}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
