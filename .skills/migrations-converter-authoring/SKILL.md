---
name: migrations-converter-authoring
description: Use when creating a new converter (support for a new source system) in migrations/converters or private/converters — covers directory discovery, the Zeitwerk namespace collapse, converter.rb, settings files, step discovery, step_args, and running disco convert
---

# Adding a converter

A converter turns one source system's data into the IntermediateDB. It is not
registered anywhere — it is **discovered by directory**. For writing the steps
inside a converter, load `.skills/migrations-converter-step-authoring`.

## Directory discovery

`Migrations::Converters.all` (`migrations/converters/lib/migrations/converters.rb`)
scans two roots and maps directory basename (lowercased) → converter:

- **Public:** `migrations/converters/lib/migrations/converters/<name>/`
  (`adapter/` and `cli/` are framework dirs, excluded via `NON_CONVERTER_DIRS`)
- **Private (closed source):** `migrations/private/converters/<name>/` — gitignored —
  or any path via `MIGRATIONS_PRIVATE_CONVERTERS_PATH`

The directory name **is** the converter name (`bin/disco convert <name>`).
A name that exists in both roots raises at boot.

## Minimum skeleton

```
converters/lib/migrations/converters/mybb/
├── converter.rb     # Migrations::Converters::Mybb::Converter < ::Migrations::Conversion::Base
├── settings.yml     # committed defaults
└── steps/
    ├── users.rb     # one Step subclass per file
    └── ...
```

## The Zeitwerk namespace collapse

Every subdirectory of a converter is **collapsed** into the converter's module
(`converters.rb`, `loader`): `discourse/steps/users.rb` defines
`Migrations::Converters::Discourse::Users` — **not** `...::Discourse::Steps::Users`.

This is required by step discovery (see below), which scans the converter
module's constants. Consequences:

- Never nest a module for a subdirectory (`module Steps` breaks loading).
- File basenames must be unique across all subdirectories of one converter —
  `steps/users.rb` and `utilities/users.rb` would define the same constant.

## converter.rb

```ruby
# frozen_string_literal: true

module Migrations
  module Converters
    module Mybb
      class Converter < ::Migrations::Conversion::Base
        # Steps run concurrently and a DB connection can't be shared across
        # them, so each step gets its own adapter; the step's source closes
        # it in its `cleanup`.
        def step_args(step_class)
          { source_db: Adapter::Postgres.new(settings[:source_db]) }
        end
      end
    end
  end
end
```

- `step_args(step_class)` is merged over the default `{ settings: }`
  (`core/lib/migrations/conversion/base.rb`, `create_step`) — it's the hook for
  per-step resources. Hand out **one connection per step**, never a shared one.
- An optional `setup` method runs once before the database is created
  (use it for source-wide sanity checks).
- The source adapter must be fork safe — see "Source DB adapters and fork
  safety" in `migrations/README.md` before wiring up a new client library.

## Settings

- Loaded with `YAML.safe_load(..., symbolize_names: true)` — access via
  `settings[:source_db]` etc.
- `intermediate_db.path` is required; a relative path resolves against the
  `migrations/core` gem root, so prefer an absolute path.
- All other keys are converter-specific. By convention `source_db` holds the
  connection parameters passed straight to the adapter (for local Postgres, a
  Unix socket with peer auth is the simplest: set `host` to the socket
  directory, drop `port`/`user`/`password`).
- A `settings.local.yml` next to `settings.yml` silently wins as the default
  settings file (`Converters.default_settings_path`) — use it for local
  credentials. It is gitignored (`migrations/.gitignore`).
- `--settings <path>` overrides both.

## Step discovery and ordering

`Conversion::Base#steps` collects all `Step` subclasses among the converter
module's constants and orders them with `TopologicalSorter` from the
dependencies each step declares. There is no step list to maintain — dropping
a file into `steps/` is enough. `--only`/`--skip` filter **after** sorting, so
re-running a single step keeps working even when it declares dependencies.

## Running

```bash
migrations/bin/disco convert mybb                      # default settings file
migrations/bin/disco convert mybb --settings path.yml
migrations/bin/disco convert mybb --reset              # delete intermediate DB first
migrations/bin/disco convert mybb --only users,topics  # comma-separated step names
migrations/bin/disco convert mybb --skip posts
migrations/bin/disco convert mybb --no-fork            # serial, in-process — a breakpoint
                                                       # in a step stops in the main run
migrations/bin/disco convert mybb --max-parallel-steps 4
```

`convert` does not boot Rails.

## Review checklist

1. Directory basename is the converter name — lowercase, no clash with an
   existing public or private converter
2. `converter.rb` defines `...::<Name>::Converter < ::Migrations::Conversion::Base`
3. No `module Steps`-style nesting; file basenames unique across the
   converter's subdirectories
4. `settings.yml` committed with placeholder credentials; real credentials in
   `settings.local.yml` only
5. `intermediate_db.path` present (absolute path)
6. `step_args` creates per-step resources; nothing connection-like is shared
   across steps
7. New source adapters follow the fork-safety pattern (`ForkManager.after_fork_child`
   + `discard!`; see `migrations/README.md` and `postgres_spec.rb`)
