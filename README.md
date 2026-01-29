# claude-cli Zsh 插件

`claude-cli` 是一个将 Claude CLI 集成到 Zsh 中的插件。

## 使用方法

- 在 Zsh 中按 `Ctrl-X` 开始与 Claude CLI 对话。
- 再次按 `Ctrl-X` 退出 Claude CLI 模式。

## 系统要求

- Zsh 5.4+
- `claude` 命令在 `$PATH` 中可用

## 安装方法

选择与你的 Zsh 配置相匹配的安装方式。

### 手动安装（`.zshrc`）

```zsh
# 克隆到任意目录
git clone https://github.com/jerryokk/zsh-claude-cli.git ~/.zsh/claude-cli

# 在 .zshrc 中加载插件
source ~/.zsh/claude-cli/claude-cli.plugin.zsh
```

打开新的 shell（或执行 `exec zsh`）以激活插件。

### Oh My Zsh

```zsh
git clone https://github.com/jerryokk/zsh-claude-cli.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/claude-cli

# 在 ~/.zshrc 中添加
plugins=(... claude-cli)
```

重新加载 Zsh 以启用插件。

### Antigen

```zsh
antigen bundle jerryokk/zsh-claude-cli
antigen apply
```

### Zinit

```zsh
zinit light jerryokk/zsh-claude-cli
```

### Znap

```zsh
znap source jerryokk/zsh-claude-cli
```

### Fig

```zsh
fig plugin install jerryokk/zsh-claude-cli
```

### Zplug

```zsh
zplug "jerryokk/zsh-claude-cli", as:plugin
```
