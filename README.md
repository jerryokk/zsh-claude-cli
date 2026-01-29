# claude-cli Zsh/Bash 插件

`claude-cli` 是一个将 Claude CLI 集成到 Zsh 和 Bash 中的插件。

## 使用方法

- 在 Zsh/Bash 中按 `Ctrl-X` 切换 AI 模式。
- AI 模式下，提示符会显示 ✨ 前缀。
- 在 AI 模式下输入任何内容，将发送给 Claude 处理。
- 再次按 `Ctrl-X` 退出 AI 模式。

## 会话管理

插件使用智能的会话持久化机制：

- **首次启动**：在 AI 模式下第一次与 Claude 对话时，插件会记录当前工作目录作为"原始目录"
- **跨目录持久化**：当你切换到其他目录后继续使用 AI 模式，插件会：
  1. 临时切换回原始目录
  2. 以原始目录的上下文继续 Claude 会话
  3. 执行完成后返回你的当前目录
- **透明性**：整个过程对用户透明，你无需手动管理目录或会话 ID

这样设计的好处是：
- ✅ 在任何目录都能继续同一个对话
- ✅ 利用 Claude CLI 原生的 per-project session 机制
- ✅ 保持会话的项目上下文一致性

## 系统要求

- Zsh 5.4+ 或 Bash 4.0+
- `claude` 命令在 `$PATH` 中可用

## 安装方法

### Zsh 版本

选择与你的 Zsh 配置相匹配的安装方式。

#### 手动安装（`.zshrc`）

```zsh
# 克隆到任意目录
git clone https://github.com/jerryokk/zsh-claude-cli.git ~/.zsh/claude-cli

# 在 .zshrc 中加载插件
source ~/.zsh/claude-cli/claude-cli.plugin.zsh
```

打开新的 shell（或执行 `exec zsh`）以激活插件。

#### Oh My Zsh

```zsh
git clone https://github.com/jerryokk/zsh-claude-cli.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/claude-cli

# 在 ~/.zshrc 中添加
plugins=(... claude-cli)
```

重新加载 Zsh 以启用插件。

#### Antigen

```zsh
antigen bundle jerryokk/zsh-claude-cli
antigen apply
```

#### Zinit

```zsh
zinit light jerryokk/zsh-claude-cli
```

#### Znap

```zsh
znap source jerryokk/zsh-claude-cli
```

#### Fig

```zsh
fig plugin install jerryokk/zsh-claude-cli
```

#### Zplug

```zsh
zplug "jerryokk/zsh-claude-cli", as:plugin
```

### Bash 版本

对于 Bash 用户，可以使用 `claude-cli.bash`：

```bash
# 克隆仓库
git clone https://github.com/jerryokk/zsh-claude-cli.git ~/.bash/claude-cli

# 在 ~/.bashrc 中添加
source ~/.bash/claude-cli/claude-cli.bash
```

重新加载 Bash 以启用插件：

```bash
source ~/.bashrc
```

**注意**：Bash 版本由于 readline 限制，按 `Ctrl-X` 后需要按 `Enter` 才能看到提示符的变化。
