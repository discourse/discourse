# frozen_string_literal: true

# Tasks for maintaining db/structure.sql.

module DbStructure
  BOOKKEEPING_TABLES = %w[schema_migrations schema_migration_details ar_internal_metadata].freeze

  # PG 17+ pg_dump changes output format. Pin to 15/16 for now:
  PG_DUMP_VERSIONS = (15..16)

  def self.temp_db_env
    bundled = `script/list_bundled_plugins`.split.map { |p| File.basename(p) }.join(",")
    {
      "RAILS_ENV" => "test",
      "LOAD_PLUGINS" => bundled,
      "SKIP_SEED_FU" => "1",
      "SKIP_OPTIMIZE_ICONS" => "1",
    }
  end

  def self.with_temp_db
    require "temporary_db"

    db = TemporaryDb.new(versions: PG_DUMP_VERSIONS, port: ENV["TEMPORARY_DB_PORT"]&.to_i)
    db.start
    begin
      db.with_env { yield }
    ensure
      db.stop
      db.remove
    end
  end
end

desc "Migrate a clean disposable database and dump its schema to db/structure.sql"
task "db:dump_structure" => :environment do
  candidate = "db/structure-new.sql"
  FileUtils.rm_f(candidate)

  DbStructure.with_temp_db do
    env = DbStructure.temp_db_env
    system(
      DbStructure.temp_db_env.merge("SCHEMA" => candidate),
      "bin/rails",
      "db:migrate",
      "db:schema:dump",
      exception: true,
    )
  end

  FileUtils.mv(candidate, "db/structure.sql")
  STDERR.puts "Wrote db/structure.sql"
end

desc "CI guard: db/structure.sql is up-to-date and migrations leave no unexpected rows"
task "db:check_structure_dump" => :environment do
  require "open3"
  candidate = "db/structure-new.sql"
  FileUtils.rm_f(candidate)

  DbStructure.with_temp_db do
    # SCHEMA points at a path that doesn't yet exist, so `db:migrate` skips
    # the schema-load shortcut and `db:schema:dump` writes the fresh dump
    # there — one Rails boot for all the tasks.
    system(
      DbStructure.temp_db_env.merge("SCHEMA" => candidate),
      "bin/rails",
      "db:migrate",
      "db:check_structure_dump:assert_no_unexpected_rows",
      "db:check_structure_dump:assert_fresh_sequences",
      "db:schema:dump",
      exception: true,
    )

    diff, status = Open3.capture2("diff", "-u", "db/structure.sql", candidate)
    next if status.success?

    max_lines = 200
    lines = diff.lines
    shown = lines.first(max_lines).join
    truncation = lines.length > max_lines ? "\n[diff truncated; run locally for the full diff]" : ""

    abort <<~MSG.strip
      db/structure.sql is out of date. Run:

        bin/rake db:dump_structure

      and commit the regenerated file. Diff:

      #{shown}#{truncation}
    MSG
  end

  STDERR.puts "db/structure.sql is up-to-date and migrations leave no unexpected rows."
ensure
  FileUtils.rm_f(candidate) if candidate
end

task "db:check_structure_dump:assert_no_unexpected_rows" => :environment do
  conn = ActiveRecord::Base.connection
  unexpected =
    (conn.tables - DbStructure::BOOKKEEPING_TABLES).filter_map do |table|
      quoted = conn.quote_table_name(table)
      next if DB.query_single("SELECT 1 FROM #{quoted} LIMIT 1").empty?
      count = DB.query_single("SELECT count(*) FROM #{quoted}").first
      "#{table} (#{count} rows)"
    end

  next if unexpected.empty?

  abort <<~MSG.strip
    A fresh `db:migrate` (no seeds) left rows in application tables. `db/structure.sql`
    only captures schema, so any data a migration writes on a fresh DB silently disappears
    on installs provisioned from the dump. Move the data into a seed fixture under
    `db/fixtures/` (or a plugin's `db/fixtures/`) and, if any of the original migration
    body needs to run on upgrade paths, gate it on `Migration::Helpers.existing_site?`.

    Unexpected rows:
      - #{unexpected.join("\n  - ")}
  MSG
end

task "db:check_structure_dump:assert_fresh_sequences" => :environment do
  conn = ActiveRecord::Base.connection
  bookkeeping_sequences = DbStructure::BOOKKEEPING_TABLES.map { |t| "#{t}_id_seq" }
  sequences =
    DB.query("SELECT sequencename, start_value FROM pg_sequences WHERE schemaname = 'public'")

  non_fresh_sequences =
    sequences.filter_map do |seq|
      next if bookkeeping_sequences.include?(seq.sequencename)
      qualified = "public.#{conn.quote_column_name(seq.sequencename)}"
      row = DB.query("SELECT last_value, is_called FROM #{qualified}").first
      next if !row.is_called && row.last_value == seq.start_value
      "#{seq.sequencename} (last_value=#{row.last_value}, is_called=#{row.is_called}, start=#{seq.start_value})"
    end

  next if non_fresh_sequences.empty?

  abort <<~MSG.strip
    A fresh `db:migrate` advanced one or more sequences past their start values.
    `db/structure.sql` captures `start_value` but not runtime `last_value` /
    `is_called`, so any `setval` (or `nextval` triggered by an INSERT) silently
    reverts on installs provisioned from the dump.

    Use `ALTER SEQUENCE my_id_seq START WITH N` — pg_dump preserves it in
    structure.sql so fresh installs land at the right place.

    Non-fresh sequences:
      - #{non_fresh_sequences.join("\n  - ")}
  MSG
end

Rake::Task["db:schema:dump"].enhance do
  filename = ENV["SCHEMA"] || "db/structure.sql"
  next unless File.exist?(filename)

  contents = File.read(filename)

  # `COMMENT ON EXTENSION` requires extension ownership, which we might not have.
  # It's not essential - strip it out.
  contents.gsub!(
    /^--\n-- Name: EXTENSION [^;]+; Type: COMMENT;[^\n]*\n--\n\nCOMMENT ON EXTENSION [^\n]+\n\n\n/,
    "",
  )
  File.write(filename, contents)
end
