# Migrations Tooling — Agent Guide

Start with **[README.md](README.md)** — it is the single source of truth for this
project: gem layout and namespaces, the `disco` CLI, converters, the schema DSL,
and the install / test / lint workflow.

This file is reserved for **agent-specific** guidance that does not belong in the
README (conventions, gotchas, do/don't notes for automated contributors).

## Gotchas

- **Samovar reserves `name` on commands.** `Nested#parse` instantiates a
  sub-command with `name:` (its invocation name), which Samovar stores and exposes
  as `name`. So don't declare a positional `one :name` on a `disco` command — when
  the argument is omitted the accessor silently reads back the command's own name
  (e.g. a `schema add` command would read back `"add"`) instead of `nil`. Name the
  positional something else (`one :table_name, …`).

- **Samovar positionals are never required.** Don't use `one :x, required: true` —
  it raises during parsing, before `call` runs, which breaks the `-h/--help`
  handling. Leave positionals optional and validate them at the top of `call` with
  `require_positional!` (see `Migrations::CLI::Command`); it raises a presentable
  error, so the user gets a clean message instead of a backtrace.

- **Don't give command groups a `-h/--help` option.** The option hoisting in
  `Command#parse` moves recognized flags to the front, so a group-level help
  option steals `--help` from the subcommands — `group sub --help` would run
  the subcommand instead of printing its help. Leave groups without options;
  a bare `group --help` surfaces as an unparsable token, which `Bootstrap`
  turns into usage with exit 0.
