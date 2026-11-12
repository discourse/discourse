# frozen_string_literal: true

require "migrations-core"

# `pg` isn't safe to `require` from several threads at once: doing so races
# pg.rb's own body and it re-initializes its constants with a warning. The
# Postgres adapter that pulls it in is autoloaded lazily and first referenced
# inside the scheduler's concurrent coordinator threads and forks, so load it
# here on the main thread, before any of that starts.
require "pg"

require_relative "migrations/converters"
