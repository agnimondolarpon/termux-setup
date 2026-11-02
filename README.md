# termux-setup

A reproducible [Termux](https://termux.dev) environment for C/C++ development and security work:
**zsh** with a Kali-style prompt, autosuggestions, syntax highlighting, a Tokyo Night colour
scheme, tuned extra-keys, compile-and-run helpers, and a package installer that only installs
or upgrades what is actually missing or outdated.

![Platform](https://img.shields.io/badge/platform-Termux-black)
![Shell](https://img.shields.io/badge/shell-zsh-blue)
![License](https://img.shields.io/badge/license-MIT-green)

```
┌──(agni@ANDROID)- [~/projects/]
└─$ c hello.c
```

## Features

- **One-command shell setup** - `install.sh` runs fine from Termux's default bash: it installs zsh
  first, then the plugins and dotfiles, then makes zsh your default shell.
- **Smart package installer** - `install-pkg.sh` installs missing packages, upgrades outdated ones
  and skips anything already at the latest version. Unknown packages are reported, not fatal.
- **Grouped package lists** - plain text files in `packages/`: `base`, `dev`, `security`, `extra`.
- **Kali-style two-line prompt** with Tokyo Night colours.
- **`c` / `cpp` helpers** - compile with clang (`-Wall -Wextra -pedantic -g`) and run in one step.
- **Extra-keys tuned for C** - `{ } & * | ;` plus `Esc`, `Tab`, `Ctrl`, `Alt`, arrows and paging.
- **Safe and repeatable** - existing dotfiles are backed up (`.bak.<timestamp>`); every script can be
  run again; `backup.sh` pulls your live config back into the repo.
- Neovim is installed but **its configuration is intentionally not managed here**.

## Quick start

```sh
pkg install -y git
git clone https://github.com/agnimondolarpon/termux-setup.git ~/termux-setup
cd ~/termux-setup

./install.sh --packages      # shell + dotfiles, then every tool group
```

Close and reopen Termux (or run `exec zsh`).

If the scripts are not executable (for example after downloading a ZIP), run them with `bash`:

```sh
bash install.sh --packages
```

Prefer to do it in two steps?

```sh
./install.sh         # zsh, plugins, dotfiles
./install-pkg.sh     # base + dev + security tools
```

## What the scripts do

### `install.sh`

1. Refreshes the package index and installs/upgrades **zsh** and **git** (the bootstrap).
2. Clones `zsh-autosuggestions` and `zsh-syntax-highlighting` into `~/.zsh/plugins/`.
3. Installs `~/.zshrc`, `~/.termux/termux.properties` and `~/.termux/colors.properties`.
   A differing existing file is renamed to `<file>.bak.<timestamp>` first.
4. Sets zsh as the default shell and runs `termux-reload-settings`.

| Option         | Effect                                                              |
|----------------|---------------------------------------------------------------------|
| `--packages`   | run `install-pkg.sh` (base + dev + security) when finished          |
| `--link`       | symlink dotfiles instead of copying (keep the repo where it is)     |
| `--no-pkg`     | skip installing zsh/git                                             |
| `--no-plugins` | skip cloning the zsh plugins                                        |
| `--no-chsh`    | keep the current default shell                                      |
| `-h, --help`   | show usage                                                          |

### `install-pkg.sh`

For every package in the selected groups:

| State                         | Action                         |
|-------------------------------|--------------------------------|
| not installed                 | installed                      |
| installed, newer version out  | upgraded to the latest version |
| installed, already latest     | skipped                        |
| not available in the repos    | reported and skipped           |

Only the packages in the lists are touched. A summary is printed at the end, and the exit code is
non-zero if any package failed to install.

| Option             | Effect                                                              |
|--------------------|---------------------------------------------------------------------|
| `-g, --group LIST` | comma-separated groups, e.g. `-g base,dev`                          |
| `-a, --all`        | every group, including `extra`                                      |
| `-l, --list`       | print groups and their packages, then exit                          |
| `-n, --dry-run`    | show what would change without changing anything                    |
| `--no-update`      | do not refresh the package index first                              |
| `--full-upgrade`   | upgrade every installed package first (`pkg upgrade`)               |
| `--with-repos`     | enable `unstable-repo` for extra tools (e.g. Metasploit)            |

```sh
./install-pkg.sh --dry-run          # preview
./install-pkg.sh -g dev             # only the dev toolchain
./install-pkg.sh --all              # everything, including extras
./install-pkg.sh --with-repos       # also enable the unstable repo
```

> Termux is a rolling distribution. Upgrading only some packages can occasionally leave libraries
> out of sync; if something misbehaves afterwards, run `./install-pkg.sh --full-upgrade`.

## Package groups

Edit the files in `packages/` to taste - one package per line, `#` starts a comment.

| Group      | Default | Contents                                                                                          |
|------------|:-------:|---------------------------------------------------------------------------------------------------|
| `base`     |   yes   | zsh, git, curl, wget, openssh, neovim, nano, tmux, man, ripgrep, fd, fzf, bat, jq, htop, termux-api … |
| `dev`      |   yes   | clang, make, cmake, ninja, gdb, lldb, bear, ccache, strace, ltrace, python, nodejs, golang, rust, gh … |
| `security` |   yes   | nmap, masscan, hydra, john, sqlmap, nikto, tcpdump, tshark, socat, tor, radare2, ffuf, openssl …   |
| `extra`    |   no    | fastfetch, figlet, ncdu, rsync, sqlite, android-tools, ruby, php, openjdk-17                       |

Run `./install-pkg.sh --list` for the exact, current lists. Packages that do not exist in your
enabled repositories are skipped and listed in the summary.

> **Responsible use.** The `security` group contains tools that can be harmful when misused.
> Use them only on systems you own or have explicit written permission to test.

## Repository layout

```
termux-setup/
├── install.sh              # shell + dotfiles setup (bash -> zsh)
├── install-pkg.sh          # package installer / upgrader
├── backup.sh               # copy live config from $HOME back into the repo
├── lib/
│   └── common.sh           # shared helpers (logging, package state)
├── packages/
│   ├── base.txt
│   ├── dev.txt
│   ├── security.txt
│   └── extra.txt
├── zsh/
│   └── zshrc               -> ~/.zshrc
└── termux/
    ├── termux.properties   -> ~/.termux/termux.properties
    └── colors.properties   -> ~/.termux/colors.properties
```

## Customisation

**Prompt.** The prompt keeps the Kali look. Change the name shown in it at the top of
`zsh/zshrc`, or export the variables from `~/.zshenv`:

```sh
export PROMPT_USER=kali
export PROMPT_HOST=phone
export PROMPT_SEP=@        # a circled-at glyph works with a Nerd/Unicode font
```

**Colours.** Edit `termux/colors.properties`, then run `termux-reload-settings`.

**Extra keys.** Edit the `extra-keys` line in `termux/termux.properties`.

**Font.** For the real Kali separator and icons, install a Nerd Font through Termux:Styling or
place it at `~/.termux/font.ttf`.

**Syntax highlighting.** Commands are green and unknown tokens red. Set a style to `'none'` in
`zsh/zshrc` to turn it off.

## C and C++ helpers

```sh
c hello.c            # clang -std=c17   -g -Wall -Wextra -pedantic, then run
cpp hello.cpp        # clang++ -std=c++17 ...
c prog.c arg1 arg2   # extra arguments are passed to the program
```

The source is copied to `$TS_SRC_DIR` (default `~/root/project/src`) and the binary is built next
to it. Override `TS_SRC_DIR`, `TS_CC` or `TS_CXX` to change the location or compiler
(for example `TS_CC=gcc`).

## Keeping the repo up to date

After changing your live configuration:

```sh
./backup.sh
git add -A && git commit -m "update config"
git push
```

## Troubleshooting

| Problem                                | Fix                                                                  |
|----------------------------------------|----------------------------------------------------------------------|
| Prompt shows boxes instead of symbols  | Install a Nerd Font, or keep `PROMPT_SEP=@`                          |
| `chsh` failed                          | Run `chsh -s zsh` manually, then restart Termux                      |
| Packages reported as unavailable       | Run `termux-change-repo`, or try `./install-pkg.sh --with-repos`     |
| Download or mirror errors              | Run `termux-change-repo` and pick another mirror                     |
| Want the old config back               | `mv ~/.zshrc.bak.<timestamp> ~/.zshrc`                               |
| Plugins not loading                    | Run `./install.sh --no-pkg` to re-clone them into `~/.zsh/plugins/`  |

Install Termux from [F-Droid](https://f-droid.org/packages/com.termux/) or the
[GitHub releases](https://github.com/termux/termux-app/releases); the Google Play build is no longer maintained.

## Uninstall

```sh
chsh -s bash
rm -rf ~/.zsh ~/.zshrc ~/.zsh_history ~/.cache/zsh
# restore any ~/*.bak.<timestamp> files you want back
```

## License

[MIT](LICENSE)
