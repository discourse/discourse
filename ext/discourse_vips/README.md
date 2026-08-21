# Discourse libvips helper

This native helper implements fixed Discourse image operations. Its source and
build tooling were reduced from `safe_image` commits
`18bc7a17313b50a831cf9cada6046b9d6906e377` and
`92d0850a96dff0601da4620bccebd680afb7f3de`.

The build requires libvips 8.13 or newer, its development headers, a C
compiler, and `pkg-config`.

On macOS:

```sh
brew install vips pkgconf
bundle install
```

On Ubuntu 24.04 or current Debian:

```sh
sudo apt update
sudo apt install build-essential pkg-config libvips-dev
bundle install
```
