#!/bin/bash
# Claude CLI Bash 插件 - 使用 Ctrl-X 切换 AI 模式

# 保存原始提示符
if [ -z "$__CLAUDE_CLI_ORIGINAL_PS1" ]; then
    __CLAUDE_CLI_ORIGINAL_PS1="$PS1"
fi

# 全局变量
__CLAUDE_CLI_AI_MODE=0
__CLAUDE_CLI_SESSION_FILE="/tmp/.claude-session-$$"

# 动态设置提示符
__claude_cli_set_prompt() {
    if [ "$__CLAUDE_CLI_AI_MODE" = "1" ]; then
        PS1="${__CLAUDE_CLI_ORIGINAL_PS1}✨ "
    else
        PS1="$__CLAUDE_CLI_ORIGINAL_PS1"
    fi
}

# 将提示符函数添加到 PROMPT_COMMAND（避免重复添加）
if [[ "$PROMPT_COMMAND" != *"__claude_cli_set_prompt"* ]]; then
    if [ -n "$PROMPT_COMMAND" ]; then
        PROMPT_COMMAND="__claude_cli_set_prompt; $PROMPT_COMMAND"
    else
        PROMPT_COMMAND="__claude_cli_set_prompt"
    fi
fi

# 切换 AI 模式
__claude_cli_toggle_mode() {
    # 清空当前输入行
    READLINE_LINE=""
    READLINE_POINT=0
    
    if [ "$__CLAUDE_CLI_AI_MODE" = "0" ]; then
        __CLAUDE_CLI_AI_MODE=1
    else
        __CLAUDE_CLI_AI_MODE=0
        rm -f "$__CLAUDE_CLI_SESSION_FILE"
    fi
}

# 绑定 Ctrl-X 到切换函数
# bind -x 可以重复调用，会覆盖之前的绑定
bind -x '"\C-x": __claude_cli_toggle_mode' 2>/dev/null

# 命令未找到处理器
command_not_found_handle() {
    if [ "$__CLAUDE_CLI_AI_MODE" = "1" ]; then
        # 构建完整命令
        local full_cmd="$*"
        
        # 空命令直接返回
        if [ -z "$full_cmd" ]; then
            return 0
        fi
        
        # 会话管理
        local session_id=""
        local session_started=0
        
        if [ -f "$__CLAUDE_CLI_SESSION_FILE" ]; then
            source "$__CLAUDE_CLI_SESSION_FILE"
        fi
        
        if [ -z "$session_id" ]; then
            session_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$$-$RANDOM")
            session_started=0
        fi
        
        if [ "$session_started" = "0" ]; then
            claude --dangerously-skip-permissions --session-id "$session_id" -p "$full_cmd"
            local ret=$?
            echo "session_id='$session_id'" > "$__CLAUDE_CLI_SESSION_FILE"
            echo "session_started=1" >> "$__CLAUDE_CLI_SESSION_FILE"
            return $ret
        else
            claude --dangerously-skip-permissions --resume "$session_id" -p "$full_cmd"
            return $?
        fi
    else
        echo "bash: $1: command not found" >&2
        return 127
    fi
}

# 清理函数
trap "rm -f '$__CLAUDE_CLI_SESSION_FILE' 2>/dev/null" EXIT
