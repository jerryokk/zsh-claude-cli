#!/bin/bash
# Claude CLI Bash 插件 - 使用 Ctrl-X 切换 AI 模式

# 保存原始提示符
if [ -z "$__CLAUDE_CLI_ORIGINAL_PS1" ]; then
    __CLAUDE_CLI_ORIGINAL_PS1="$PS1"
fi

# 全局变量
__CLAUDE_CLI_AI_MODE=0
__CLAUDE_CLI_SESSION_FILE="/tmp/.claude-session-$$"
__CLAUDE_CLI_ORIGIN_DIR_FILE="/tmp/.claude-origin-dir-$$"

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
        rm -f "$__CLAUDE_CLI_SESSION_FILE" "$__CLAUDE_CLI_ORIGIN_DIR_FILE"
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
        
        # 记录或读取原始目录
        local origin_dir=""
        if [ "$session_started" = "0" ]; then
            # 第一次启动，记录当前目录
            origin_dir="$PWD"
            echo "$origin_dir" > "$__CLAUDE_CLI_ORIGIN_DIR_FILE"
        else
            # 读取原始目录
            if [ -f "$__CLAUDE_CLI_ORIGIN_DIR_FILE" ]; then
                origin_dir=$(cat "$__CLAUDE_CLI_ORIGIN_DIR_FILE")
            else
                origin_dir="$PWD"
            fi
        fi
        
        # 保存当前目录
        local current_dir="$PWD"
        
        # 如果当前目录与原始目录不同，在命令后附加当前目录信息
        if [ "$current_dir" != "$origin_dir" ]; then
            full_cmd="$full_cmd (当前工作目录: $current_dir)"
        fi
        
        # 临时切换到原始目录（如果不同）
        if [ "$current_dir" != "$origin_dir" ]; then
            cd "$origin_dir" 2>/dev/null || true
        fi
        
        if [ "$session_started" = "0" ]; then
            claude --dangerously-skip-permissions --session-id "$session_id" -p "$full_cmd"
            local ret=$?
            echo "session_id='$session_id'" > "$__CLAUDE_CLI_SESSION_FILE"
            echo "session_started=1" >> "$__CLAUDE_CLI_SESSION_FILE"
        else
            claude --dangerously-skip-permissions --resume "$session_id" -p "$full_cmd"
            ret=$?
        fi
        
        # 返回原始工作目录
        if [ "$current_dir" != "$origin_dir" ]; then
            cd "$current_dir" 2>/dev/null || true
        fi
        
        return $ret
    else
        echo "bash: $1: command not found" >&2
        return 127
    fi
}

# 清理函数
trap "rm -f '$__CLAUDE_CLI_SESSION_FILE' '$__CLAUDE_CLI_ORIGIN_DIR_FILE' 2>/dev/null" EXIT
