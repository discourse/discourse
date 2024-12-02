# frozen_string_literal: true

# we should set the locale before the migration
task "set_locale" do
  begin
    I18n.locale =
      begin
        (SiteSetting.default_locale || :en)
      rescue StandardError
        :en
      end
  rescue I18n::InvalidLocale
    I18n.locale = :en
  end
end

module MultisiteTestHelpers
  def self.load_multisite?
    Rails.env.test? && !ENV["RAILS_DB"] && !ENV["SKIP_MULTISITE"]
  end

  def self.create_multisite?
    (ENV["RAILS_ENV"] == "test" || !ENV["RAILS_ENV"]) && !ENV["RAILS_DB"] &&
      !ENV["SKIP_MULTISITE"] && !ENV["SKIP_TEST_DATABASE"]
  end
end

task "db:environment:set" => [:load_config] do |_, args|
  if MultisiteTestHelpers.load_multisite?
    system(
      "RAILS_ENV=test RAILS_DB=discourse_test_multisite rake db:environment:set",
      exception: true,
    )
  end
end

task "db:force_skip_persist" do
  GlobalSetting.skip_db = true
  GlobalSetting.skip_redis = true
end

task "db:create" => [:load_config] do |_, args|
  if MultisiteTestHelpers.create_multisite?
    unless system("RAILS_ENV=test RAILS_DB=discourse_test_multisite rake db:create")
      STDERR.puts "-" * 80
      STDERR.puts "ERROR: Could not create multisite DB. A common cause of this is a plugin"
      STDERR.puts "checking the column structure when initializing, which raises an error."
      STDERR.puts "-" * 80
      raise "Could not initialize discourse_test_multisite"
    end
  end
end

begin
  reqs = Rake::Task["db:create"].prerequisites.map(&:to_sym)
  Rake::Task["db:create"].clear_prerequisites
  Rake::Task["db:create"].enhance(["db:force_skip_persist"] + reqs)
end

task "db:drop" => [:load_config] do |_, args|
  if MultisiteTestHelpers.create_multisite?
    system("RAILS_DB=discourse_test_multisite RAILS_ENV=test rake db:drop", exception: true)
  end
end

begin
  Rake::Task["db:migrate"].clear
  Rake::Task["db:rollback"].clear
end

task "db:rollback" => %w[environment set_locale] do |_, args|
  step = ENV["STEP"] ? ENV["STEP"].to_i : 1
  ActiveRecord::Base.connection_pool.migration_context.rollback(step)
  Rake::Task["db:_dump"].invoke
end

# our optimized version of multisite migrate, we have many sites and we have seeds
# this ensures we can run migrations concurrently to save huge amounts of time
Rake::Task["multisite:migrate"].clear

class StdOutDemux
  def initialize(stdout)
    @stdout = stdout
    @data = {}
  end

  def write(data)
    (@data[Thread.current] ||= +"") << data
  end

  def close
    finish_chunk
  end

  def finish_chunk
    data = @data[Thread.current]
    if data
      @stdout.write(data)
      @data.delete Thread.current
    end
  end

  def flush
    # Do nothing
  end
end

class SeedHelper
  def self.paths
    DiscoursePluginRegistry.seed_paths
  end

  def self.filter
    # Allows a plugin to exclude any specified seed data files from running
    if DiscoursePluginRegistry.seedfu_filter.any?
      /\A(?!.*(#{DiscoursePluginRegistry.seedfu_filter.to_a.join("|")})).*\z/
    else
      nil
    end
  end
end

task "multisite:migrate" => %w[
       db:load_config
       environment
       set_locale
       assets:precompile:theme_transpiler
     ] do |_, args|
  raise "Multisite migrate is only supported in production" if ENV["RAILS_ENV"] != "production"

  DistributedMutex.synchronize(
    "db_migration",
    redis: Discourse.redis.without_namespace,
    validity: 1200,
  ) do
    # TODO: Switch to processes for concurrent migrations because Rails migration
    # is not thread safe by default.
    concurrency = 1

    puts "Multisite migrator is running using #{concurrency} threads"
    puts

    exceptions = Queue.new

    if concurrency > 1
      old_stdout = $stdout
      $stdout = StdOutDemux.new($stdout)
    end

    SeedFu.quiet = true

    def execute_concurrently(concurrency, exceptions)
      queue = Queue.new

      RailsMultisite::ConnectionManagement.each_connection { |db| queue << db }

      concurrency.times { queue << :done }

      (1..concurrency)
        .map do
          Thread.new do
            while true
              db = queue.pop
              break if db == :done

              RailsMultisite::ConnectionManagement.with_connection(db) do
                begin
                  yield(db) if block_given?
                rescue => e
                  exceptions << [db, e]
                ensure
                  begin
                    $stdout.finish_chunk if concurrency > 1
                  rescue => ex
                    STDERR.puts ex.inspect
                    STDERR.puts ex.backtrace
                  end
                end
              end
            end
          end
        end
        .each(&:join)
    end

    def check_exceptions(exceptions)
      if exceptions.length > 0
        STDERR.puts
        STDERR.puts "-" * 80
        STDERR.puts "#{exceptions.length} migrations failed!"
        while !exceptions.empty?
          db, e = exceptions.pop
          STDERR.puts
          STDERR.puts "Failed to migrate #{db}"
          STDERR.puts e.inspect
          STDERR.puts e.backtrace
          STDERR.puts
        end
        exit 1
      end
    end

    execute_concurrently(concurrency, exceptions) do |db|
      puts "Migrating #{db}"
      ActiveRecord::Tasks::DatabaseTasks.migrate
    end

    check_exceptions(exceptions)

    SeedFu.seed(SeedHelper.paths, /001_refresh/)

    execute_concurrently(concurrency, exceptions) do |db|
      puts "Seeding #{db}"
      SeedFu.seed(SeedHelper.paths, SeedHelper.filter)

      if !Discourse.skip_post_deployment_migrations? && ENV["SKIP_OPTIMIZE_ICONS"] != "1"
        SiteIconManager.ensure_optimized!
      end
    end

    $stdout = old_stdout if concurrency > 1
    check_exceptions(exceptions)

    Rake::Task["db:_dump"].invoke
  end
end

task "db:migrate" => %w[
       load_config
       environment
       set_locale
       assets:precompile:theme_transpiler
     ] do |_, args|
  DistributedMutex.synchronize(
    "db_migration",
    redis: Discourse.redis.without_namespace,
    validity: 300,
  ) do
    migrations = ActiveRecord::Base.connection_pool.migration_context.migrations
    now_timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
    epoch_timestamp = Time.at(0).utc.strftime("%Y%m%d%H%M%S").to_i

    if migrations.last.version > now_timestamp
      raise "Migration #{migrations.last.version} is timestamped in the future"
    end
    if migrations.first.version < epoch_timestamp
      raise "Migration #{migrations.first.version} is timestamped before the epoch"
    end

    %i[pg_trgm unaccent].each do |extension|
      begin
        DB.exec "CREATE EXTENSION IF NOT EXISTS #{extension}"
      rescue => e
        STDERR.puts "Cannot enable database extension #{extension}"
        STDERR.puts e
      end
    end

    ActiveRecord::Tasks::DatabaseTasks.migrate

    SeedFu.quiet = true

    begin
      SeedFu.seed(SeedHelper.paths, SeedHelper.filter)
    rescue => error
      error.backtrace.each { |l| puts l }
    end

    Rake::Task["db:schema:cache:dump"].invoke if Rails.env.development? && !ENV["RAILS_DB"]

    if !Discourse.skip_post_deployment_migrations? && ENV["SKIP_OPTIMIZE_ICONS"] != "1"
      SiteIconManager.ensure_optimized!
    end
  end

  if !Discourse.is_parallel_test? && MultisiteTestHelpers.load_multisite?
    system("RAILS_DB=discourse_test_multisite rake db:migrate", exception: true)
  end
end

task "test:prepare" => "environment" do
  I18n.locale =
    begin
      SiteSetting.default_locale
    rescue StandardError
      :en
    end
  SeedFu.seed(DiscoursePluginRegistry.seed_paths)
end

task "db:api_test_seed" => "environment" do
  puts "Loading test data for discourse_api"
  load Rails.root + "db/api_test_seeds.rb"
end

def print_table(array)
  width = array[0].keys.map { |k| k.to_s.length }
  cols = array[0].keys.length

  array.each do |row|
    row.each_with_index { |(_, val), i| width[i] = [width[i].to_i, val.to_s.length].max }
  end

  array[0].keys.each_with_index do |col, i|
    print col.to_s.ljust(width[i], " ")
    if i == cols - 1
      puts
    else
      print " | "
    end
  end

  puts "-" * (width.sum + width.length)

  array.each do |row|
    row.each_with_index do |(_, val), i|
      print val.to_s.ljust(width[i], " ")
      if i == cols - 1
        puts
      else
        print " | "
      end
    end
  end
end

desc "Statistics about database"
task "db:stats" => "environment" do
  sql = <<~SQL
    select table_name,
    (
      select reltuples::bigint
      from pg_class
      where oid = ('public.' || table_name)::regclass
    ) AS row_estimate,
    pg_size_pretty(pg_table_size(quote_ident(table_name))) table_size,
    pg_size_pretty(pg_indexes_size(quote_ident(table_name))) index_size,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) total_size
    from information_schema.tables
    where table_schema = 'public'
    order by pg_total_relation_size(quote_ident(table_name)) DESC
  SQL

  puts
  print_table(DB.query_hash(sql))
end

task "db:ensure_post_migrations" do
  if %w[1 true].include?(ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"])
    cmd = `cat /proc/#{Process.pid}/cmdline | xargs -0 echo`
    ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"] = "0"
    exec cmd
  end
end

class NormalizedIndex
  attr_accessor :name, :original, :normalized, :table

  def initialize(original)
    @original = original
    @normalized = original.sub(/(create.*index )(\S+)(.*)/i, '\1idx\3')
    @name = original.match(/create.*index (\S+)/i)[1]
    @table = original.match(/create.*index \S+ on public\.(\S+)/i)[1]
  end

  def ==(other)
    other&.normalized == normalized
  end
end

def normalize_index_names(names)
  names.map { |name| NormalizedIndex.new(name) }.reject { |i| i.name.include?("ccnew") }
end

desc "Validate indexes"
task "db:validate_indexes", [:arg] => %w[db:ensure_post_migrations environment] do |_, args|
  db = TemporaryDb.new
  db.start
  db.migrate

  ActiveRecord::Base.establish_connection(
    adapter: "postgresql",
    database: "discourse",
    port: db.pg_port,
    host: "localhost",
  )

  expected = DB.query_single <<~SQL
    SELECT indexdef FROM pg_indexes
    WHERE schemaname = 'public'
    ORDER BY indexdef
  SQL

  expected_tables = DB.query_single <<~SQL
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  SQL

  ActiveRecord::Base.establish_connection

  db.stop

  puts

  fix_indexes = (ENV["FIX_INDEXES"] == "1" || args[:arg] == "fix")
  inconsistency_found = false

  RailsMultisite::ConnectionManagement.each_connection do |db_name|
    puts "Testing indexes on the #{db_name} database", ""

    current = DB.query_single <<~SQL
      SELECT indexdef FROM pg_indexes
      WHERE schemaname = 'public'
      ORDER BY indexdef
    SQL

    missing = expected - current
    extra = current - expected

    extra.reject! { |x| x =~ /idx_recent_regular_post_search_data/ }

    renames = []
    normalized_missing = normalize_index_names(missing)
    normalized_extra = normalize_index_names(extra)

    normalized_extra.each do |extra_index|
      if missing_index = normalized_missing.select { |x| x == extra_index }.first
        renames << [extra_index, missing_index]
        missing.delete missing_index.original
        extra.delete extra_index.original
      end
    end

    next if db_name != "default" && renames.length == 0 && missing.length == 0 && extra.length == 0

    if renames.length > 0
      inconsistency_found = true

      puts "Renamed indexes"
      renames.each do |extra_index, missing_index|
        puts "#{extra_index.name} should be renamed to #{missing_index.name}"
      end
      puts

      if fix_indexes
        puts "fixing indexes"

        renames.each do |extra_index, missing_index|
          DB.exec "ALTER INDEX #{extra_index.name} RENAME TO #{missing_index.name}"
        end

        puts
      end
    end

    if missing.length > 0
      inconsistency_found = true

      puts "Missing Indexes", ""
      missing.each { |m| puts m }
      if fix_indexes
        puts "Adding missing indexes..."
        missing.each do |m|
          begin
            DB.exec(m)
          rescue => e
            $stderr.puts "Error running: #{m} - #{e}"
          end
        end
      end
    else
      puts "No missing indexes", ""
    end

    if extra.length > 0
      inconsistency_found = true

      puts "", "Extra Indexes", ""
      extra.each { |e| puts e }

      if fix_indexes
        puts "Removing extra indexes"
        extra.each do |statement|
          if match = /create .*index (\S+) on public\.(\S+)/i.match(statement)
            index_name, table_name = match[1], match[2]
            if expected_tables.include?(table_name)
              puts "Dropping #{index_name}"
              begin
                DB.exec("DROP INDEX #{index_name}")
              rescue => e
                $stderr.puts "Error dropping index #{index_name} - #{e}"
              end
            else
              $stderr.puts "Skipping #{index_name} since #{table_name} should not exist - maybe an old plugin created it"
            end
          else
            $stderr.puts "ERROR - BAD REGEX - UNABLE TO PARSE INDEX - #{statement}"
          end
        end
      end
    else
      puts "No extra indexes", ""
    end
  end

  exit 1 if inconsistency_found && !fix_indexes
end

desc "Rebuild indexes"
task "db:rebuild_indexes" => "environment" do
  if Import.backup_tables_count > 0
    raise "Backup from a previous import exists. Drop them before running this job with rake import:remove_backup, or move them to another schema."
  end

  Discourse.enable_readonly_mode

  backup_schema = Jobs::Importer::BACKUP_SCHEMA
  table_names =
    DB.query_single(
      "select table_name from information_schema.tables where table_schema = 'public'",
    )

  begin
    # Move all tables to the backup schema:
    DB.exec("DROP SCHEMA IF EXISTS #{backup_schema} CASCADE")
    DB.exec("CREATE SCHEMA #{backup_schema}")
    table_names.each do |table_name|
      DB.exec("ALTER TABLE public.#{table_name} SET SCHEMA #{backup_schema}")
    end

    # Create a new empty db
    Rake::Task["db:migrate"].invoke

    # Fetch index definitions from the new db
    index_definitions = {}
    table_names.each do |table_name|
      index_definitions[table_name] = DB.query_single(
        "SELECT indexdef FROM pg_indexes WHERE tablename = '#{table_name}' and schemaname = 'public';",
      )
    end

    # Drop the new tables
    table_names.each { |table_name| DB.exec("DROP TABLE public.#{table_name}") }

    # Move the old tables back to the public schema
    table_names.each do |table_name|
      DB.exec("ALTER TABLE #{backup_schema}.#{table_name} SET SCHEMA public")
    end

    # Drop their indexes
    index_names =
      DB.query_single(
        "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('#{table_names.join("', '")}')",
      )
    index_names.each do |index_name|
      begin
        puts index_name
        DB.exec("DROP INDEX public.#{index_name}")
      rescue ActiveRecord::StatementInvalid
        # It's this:
        # PG::Error: ERROR:  cannot drop index category_users_pkey because constraint category_users_pkey on table category_users requires it
        # HINT:  You can drop constraint category_users_pkey on table category_users instead.
      end
    end

    # Create the indexes
    table_names.each do |table_name|
      index_definitions[table_name].each do |index_def|
        begin
          DB.exec(index_def)
        rescue ActiveRecord::StatementInvalid
          # Trying to recreate a primary key
        end
      end
    end
  rescue StandardError
    # Can we roll this back?
    raise
  ensure
    Discourse.disable_readonly_mode
  end
end

desc "Check that the DB can be accessed"
task "db:status:json" do
  begin
    Rake::Task["environment"].invoke
    DB.query("SELECT 1")
  rescue StandardError
    puts({ status: "error" }.to_json)
  else
    puts({ status: "ok" }.to_json)
  end
end

desc "Grow notification id column to a big int in case of overflow"
task "db:resize:notification_id" => :environment do
  sql = <<~SQL
    SELECT table_name, column_name FROM INFORMATION_SCHEMA.columns
    WHERE (column_name like '%notification_id' OR column_name = 'id' and table_name = 'notifications') AND data_type = 'integer'
  SQL

  DB
    .query(sql)
    .each do |row|
      puts "Changing #{row.table_name}(#{row.column_name}) to a bigint"
      DB.exec("ALTER table #{row.table_name} ALTER COLUMN #{row.column_name} TYPE BIGINT")
    end
end
