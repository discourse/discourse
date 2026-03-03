---
title: Automatically lint and format code before commits
short_title: Lint and format
id: lint-and-format
---

The discourse repository includes configuration for [lefthook](https://github.com/Arkweid/lefthook). This will automatically check any code before it's committed to git, and alert about any issues. To get set up, simply enter your discourse development directory and run

```sh
pnpm install
pnpm run lefthook install
```

Files will now be automatically checked before committing. If there are any issues, the commit will be cancelled, and you will be shown a list of errors.
