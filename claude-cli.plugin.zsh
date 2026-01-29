# 当命令未找到时回退到 claude

typeset -g __CLAUDE_CLI_PREFIX_CHAR
: "${__CLAUDE_CLI_PREFIX_CHAR:="✨"}"

typeset -g __CLAUDE_CLI_PREFIX
: "${__CLAUDE_CLI_PREFIX:="${__CLAUDE_CLI_PREFIX_CHAR} "}"

typeset -g __CLAUDE_CLI_PREFIX_ACTIVE=0
typeset -g __CLAUDE_CLI_WIDGETS_INSTALLED=0
typeset -g __CLAUDE_CLI_HAS_PREV_LINE_INIT=0
typeset -g __CLAUDE_CLI_HAS_PREV_LINE_PRE_REDRAW=0
typeset -g __CLAUDE_CLI_HAS_PREV_LINE_FINISH=0
typeset -gA __CLAUDE_CLI_GUARD_WIDGET_ALIASES=()

# 使用 ZSH_SUBSHELL 和 $$ 的组合确保在主 shell 和子 shell 中都能访问同一文件
typeset -g __CLAUDE_CLI_SESSION_FILE="/tmp/.claude-cli-session-${$}"

# 使用 trap 确保 shell 退出时清理会话文件
trap "rm -f '$__CLAUDE_CLI_SESSION_FILE' 2>/dev/null" EXIT

if (( $+functions[command_not_found_handler] )); then
  functions[__claude_cli_original_command_not_found_handler]=$functions[command_not_found_handler]
fi

command_not_found_handler() {
  emulate -L zsh

  local missing_command="$1"
  local -a cmd_with_args=("$@")

  shift
  local -a remaining_args=("$@")

  if [[ -z "$missing_command" ]]; then
    if (( $+functions[__claude_cli_original_command_not_found_handler] )); then
      __claude_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    return 127
  fi

  local prefix_char="${__CLAUDE_CLI_PREFIX_CHAR:-✨}"

  local handled=false
  local -a effective_cmd=()

  if [[ "$missing_command" == "$prefix_char" ]]; then
    handled=true
    effective_cmd=("${remaining_args[@]}")
  elif [[ "$missing_command" == ${prefix_char}* ]]; then
    handled=true
    local stripped="${missing_command#$prefix_char}"
    if [[ -n "$stripped" ]]; then
      effective_cmd=("$stripped" "${remaining_args[@]}")
    else
      effective_cmd=("${remaining_args[@]}")
    fi
  fi

  if [[ "$handled" != true ]]; then
    if (( $+functions[__claude_cli_original_command_not_found_handler] )); then
      __claude_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    print -u2 "zsh: command not found: ${missing_command}"
    return 127
  fi

  if (( ${#effective_cmd[@]} == 0 )); then
    return 0
  fi

  # 从文件读取会话信息
  local session_id=""
  local session_started=0
  if [[ -f "$__CLAUDE_CLI_SESSION_FILE" ]]; then
    source "$__CLAUDE_CLI_SESSION_FILE"
  fi

  if ! command -v claude >/dev/null 2>&1; then
    if (( $+functions[__claude_cli_original_command_not_found_handler] )); then
      __claude_cli_original_command_not_found_handler "${cmd_with_args[@]}"
      return $?
    fi
    print -u2 "claude: command not found; unable to handle '${effective_cmd[1]}'."
    return 127
  fi

  # 初始化会话 ID
  if [[ -z "$session_id" ]]; then
    session_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$$-$RANDOM")
    session_started=0
  fi

  local full_cmd
  full_cmd="$(printf '%q ' "${effective_cmd[@]}")"
  full_cmd="${full_cmd% }"

  # 第一次使用 --session-id，后续使用 --resume
  if (( session_started == 0 )); then
    claude --dangerously-skip-permissions --session-id "$session_id" -p "$full_cmd"
    local ret=$?
    session_started=1
    # 保存会话信息到文件
    echo "session_id='$session_id'" > "$__CLAUDE_CLI_SESSION_FILE"
    echo "session_started=$session_started" >> "$__CLAUDE_CLI_SESSION_FILE"
    return $ret
  else
    claude --dangerously-skip-permissions --resume "$session_id" -p "$full_cmd"
    return $?
  fi
}

__claude_cli_toggle_prefix() {
  emulate -L zsh

  local prefix="${__CLAUDE_CLI_PREFIX:-${__CLAUDE_CLI_PREFIX_CHAR} }"
  local prefix_len=${#prefix}

  if [[ "$BUFFER" == "$prefix"* ]]; then
    BUFFER="${BUFFER#$prefix}"
    if (( CURSOR > prefix_len )); then
      CURSOR=$(( CURSOR - prefix_len ))
    else
      CURSOR=0
    fi
    __CLAUDE_CLI_PREFIX_ACTIVE=0
    # 退出模式时删除会话文件
    rm -f "$__CLAUDE_CLI_SESSION_FILE"
  else
    BUFFER="${prefix}${BUFFER}"
    CURSOR=$(( CURSOR + prefix_len ))
    __CLAUDE_CLI_PREFIX_ACTIVE=1
  fi
}

__claude_cli_line_init() {
  emulate -L zsh

  if (( __CLAUDE_CLI_PREFIX_ACTIVE )); then
    local prefix="${__CLAUDE_CLI_PREFIX:-${__CLAUDE_CLI_PREFIX_CHAR} }"
    BUFFER="${prefix}"
    CURSOR=${#prefix}
  fi

  if (( __CLAUDE_CLI_HAS_PREV_LINE_INIT )); then
    zle __claude_cli_prev_line_init
  fi
}

__claude_cli_line_pre_redraw() {
  emulate -L zsh

  if (( __CLAUDE_CLI_PREFIX_ACTIVE )); then
    local prefix="${__CLAUDE_CLI_PREFIX:-${__CLAUDE_CLI_PREFIX_CHAR} }"
    local prefix_len=${#prefix}

    if (( CURSOR < prefix_len )); then
      CURSOR=$prefix_len
    fi

    local buffer_len=${#BUFFER}
    if (( CURSOR > buffer_len )); then
      CURSOR=$buffer_len
    fi
  fi

  if (( __CLAUDE_CLI_HAS_PREV_LINE_PRE_REDRAW )); then
    zle __claude_cli_prev_line_pre_redraw
  fi
}

__claude_cli_line_finish() {
  emulate -L zsh

  # 只有前缀时清空命令行但保持激活状态
  if (( __CLAUDE_CLI_PREFIX_ACTIVE )); then
    local prefix="${__CLAUDE_CLI_PREFIX:-${__CLAUDE_CLI_PREFIX_CHAR} }"
    if [[ "$BUFFER" == "$prefix" ]] || [[ "$BUFFER" == "${prefix% }" ]]; then
      BUFFER=""
    fi
  fi

  if (( __CLAUDE_CLI_HAS_PREV_LINE_FINISH )); then
    zle __claude_cli_prev_line_finish
  fi
}

__claude_cli_guard_backward_action() {
  emulate -L zsh

  if (( ! __CLAUDE_CLI_PREFIX_ACTIVE )); then
    __claude_cli_call_guarded_original
    return
  fi

  local prefix="${__CLAUDE_CLI_PREFIX:-${__CLAUDE_CLI_PREFIX_CHAR} }"
  local prefix_len=${#prefix}

  if [[ "$BUFFER" == "$prefix"* ]] && (( CURSOR <= prefix_len )); then
    zle beep 2>/dev/null
    return
  fi

  __claude_cli_call_guarded_original
}

__claude_cli_call_guarded_original() {
  emulate -L zsh

  local alias="${__CLAUDE_CLI_GUARD_WIDGET_ALIASES[$WIDGET]-}"
  if [[ -n "$alias" ]]; then
    zle "$alias" 2>/dev/null
  else
    zle ".${WIDGET}" 2>/dev/null
  fi
}

__claude_cli_register_guard_widget() {
  emulate -L zsh

  local widget="$1"
  local alias="__claude_cli_prev_${widget//-/_}"

  if zle -A "$widget" "$alias" 2>/dev/null; then
    __CLAUDE_CLI_GUARD_WIDGET_ALIASES[$widget]="$alias"
  else
    __CLAUDE_CLI_GUARD_WIDGET_ALIASES[$widget]=""
  fi

  zle -N "$widget" __claude_cli_guard_backward_action
}

if [[ -o interactive ]]; then
  zle -N __claude_cli_toggle_prefix

  local -a __claude_cli_keymaps=("emacs" "viins")
  local keymap
  for keymap in "${__claude_cli_keymaps[@]}"; do
    bindkey -M "$keymap" '^X' __claude_cli_toggle_prefix 2>/dev/null
  done
  unset keymap __claude_cli_keymaps

  if (( ! __CLAUDE_CLI_WIDGETS_INSTALLED )); then
    if zle -A zle-line-init __claude_cli_prev_line_init 2>/dev/null; then
      __CLAUDE_CLI_HAS_PREV_LINE_INIT=1
    fi
    zle -N zle-line-init __claude_cli_line_init

    if zle -A zle-line-pre-redraw __claude_cli_prev_line_pre_redraw 2>/dev/null; then
      __CLAUDE_CLI_HAS_PREV_LINE_PRE_REDRAW=1
    fi
    zle -N zle-line-pre-redraw __claude_cli_line_pre_redraw

    if zle -A zle-line-finish __claude_cli_prev_line_finish 2>/dev/null; then
      __CLAUDE_CLI_HAS_PREV_LINE_FINISH=1
    fi
    zle -N zle-line-finish __claude_cli_line_finish
    __claude_cli_register_guard_widget backward-delete-char
    __claude_cli_register_guard_widget backward-kill-word
    __claude_cli_register_guard_widget vi-backward-delete-char
    __claude_cli_register_guard_widget vi-backward-kill-word

    __CLAUDE_CLI_WIDGETS_INSTALLED=1
  fi
fi
