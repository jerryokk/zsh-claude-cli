# claude-cli Zsh Plugin

`claude-cli` Zsh plugin is a Zsh plugin that integrate Claude CLI into Zsh.

## Usage

- Press `Ctrl-X` in Zsh to start talking to Claude CLI.
- Press `Ctrl-X` again to exit Claude CLI mode.

## Requirements

- Zsh 5.4+
- `claude` binary available in `$PATH`

## Installation

Pick the method that matches your Zsh setup.

### Manual (`.zshrc`)

```zsh
# clone anywhere you prefer
git clone https://github.com/jerryokk/zsh-claude-cli.git ~/.zsh/claude-cli

# load the plugin in .zshrc
source ~/.zsh/claude-cli/claude-cli.plugin.zsh
```

Open a new shell (or `exec zsh`) to activate the handler.

### Oh My Zsh

```zsh
git clone https://github.com/jerryokk/zsh-claude-cli.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/claude-cli

# in ~/.zshrc
plugins=(... claude-cli)
```

Reload Zsh to pick up the plugin.

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
