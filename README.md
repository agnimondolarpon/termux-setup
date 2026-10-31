# termux-setup

My Termux environment in one repo: zsh with a Kali-style prompt, autosuggestions,
syntax highlighting, a Tokyo-Night-style color scheme, and `c` / `cpp` helper
functions that compile and run a file with clang.

## Layout

```
termux-setup/
├── install.sh                  # one-shot setup
├── backup.sh                   # copy live config from $HOME back into the repo
├── zsh/
│   └── zshrc                   -> ~/.zshrc
└── termux/
    ├── termux.properties       -> ~/.termux/termux.properties
    └── colors.properties       -> ~/.termux/colors.properties
```

The two zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`) are not
stored here. `install.sh` clones them into `~/.zsh/plugins/`, which is where
the `zshrc` looks for them.

## Install on a fresh Termux

```sh
pkg install -y git
git clone <your-repo-url> ~/termux-setup
cd ~/termux-setup
bash install.sh
```

Starting from the zip instead:

```sh
termux-setup-storage            # once, to access shared storage
pkg install -y unzip
cp ~/storage/downloads/termux-setup.zip ~ && cd ~
unzip termux-setup.zip && cd termux-setup
bash install.sh
```

Then close and reopen Termux.

### What `install.sh` does

1. `pkg install` zsh, git, clang, neovim, nano (edit `PKGS` at the top to change)
2. clones the two zsh plugins
3. installs the dotfiles; any existing file is renamed to `<name>.bak.<timestamp>` first
4. runs `chsh -s zsh` and `termux-reload-settings`

It is safe to run again. Options:

| Flag | Effect |
|------|--------|
| `--link` | symlink dotfiles instead of copying, so edits in the repo apply immediately |
| `--no-pkg` | skip package installation |
| `--no-plugins` | skip plugin cloning |
| `--no-chsh` | keep the current default shell |

## Keeping the repo up to date

After changing your live config:

```sh
bash backup.sh
git add -A && git commit -m "update config"
git push
```

## Using the `c` and `cpp` helpers

```sh
c hello.c       # compiles with clang -std=c17 -Wall -Wextra -pedantic, then runs
cpp hello.cpp   # same with clang++ -std=c++17
```

Sources are copied to `~/project/src/` and the binary is built next to them.

## Pushing to GitHub

```sh
git remote add origin https://github.com/<you>/termux-setup.git
git push -u origin main
```
