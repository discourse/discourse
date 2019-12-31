# frozen_string_literal: true

# we should set the locale before the migration
task 'set_locale' do
  begin
    I18n.locale = (SiteSetting.default_locale || :en) rescue :en
  rescue I18n::InvalidLocale
    I18n.locale = :en
  end
end

module MultisiteTestHelpers
  def self.load_multisite?
    Rails.env.test? && !ENV["RAILS_DB"] && !ENV["SKIP_MULTISITE"]
  end

  def self.create_multisite?
    (ENV["RAILS_ENV"] == "test" || !ENV["RAILS_ENV"]) && !ENV["RAILS_DB"] && !ENV["SKIP_MULTISITE"]
  end
end

task 'db:environment:set' => [:load_config]  do |_, args|
  if MultisiteTestHelpers.load_multisite?
    system("RAILS_ENV=test RAILS_DB=discourse_test_multisite rake db:environment:set")
  end
end

task 'db:force_skip_persist' do
  GlobalSetting.skip_db = true
  GlobalSetting.skip_redis = true
end

task 'db:create' => [:load_config] do |_, args|
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
  reqs = Rake::Task['db:create'].prerequisites.map(&:to_sym)
  Rake::Task['db:create'].clear_prerequisites
  Rake::Task['db:create'].enhance(["db:force_skip_persist"] + reqs)
end

task 'db:drop' => [:load_config] do |_, args|
  if MultisiteTestHelpers.create_multisite?
    system("RAILS_DB=discourse_test_multisite RAILS_ENV=test rake db:drop")
  end
end

begin
  Rake::Task["db:migrate"].clear
  Rake::Task["db:rollback"].clear
end

task 'db:rollback' => ['environment', 'set_locale'] do |_, args|
  step = ENV["STEP"] ? ENV["STEP"].to_i : 1
  ActiveRecord::Base.connection.migration_context.rollback(step)
  Rake::Task['db:_dump'].invoke
end

# we need to run seed_fu every time we run rake db:migrate
task 'db:migrate' => ['load_config', 'environment', 'set_locale'] do |_, args|

  ActiveRecord::Tasks::DatabaseTasks.migrate

  if !Discourse.is_parallel_test?
    Rake::Task['db:_dump'].invoke
  end

  SeedFu.seed(DiscoursePluginRegistry.seed_paths)

  if !Discourse.skip_post_deployment_migrations?
    puts
    print "Optimizing site icons... "
    SiteIconManager.ensure_optimized!
    puts "Done"
  end

  if !Discourse.is_parallel_test? && MultisiteTestHelpers.load_multisite?
    system("RAILS_DB=discourse_test_multisite rake db:migrate")
  end
end

task 'test:prepare' => 'environment' do
  I18n.locale = SiteSetting.default_locale rescue :en
  SeedFu.seed(DiscoursePluginRegistry.seed_paths)
end

task 'db:api_test_seed' => 'environment' do
  puts "Loading test data for discourse_api"
  load Rails.root + 'db/api_test_seeds.rb'
end

def print_table(array)
  width = array[0].keys.map { |k| k.to_s.length }
  cols = array[0].keys.length

  array.each do |row|
    row.each_with_index do |(_, val), i|
      width[i] = [width[i].to_i, val.to_s.length].max
    end
  end

  array[0].keys.each_with_index do |col, i|
    print col.to_s.ljust(width[i], ' ')
    if i == cols - 1
      puts
    else
      print ' | '
    end
  end

  puts "-" * (width.sum + width.length)

  array.each do |row|
    row.each_with_index do |(_, val), i|
      print val.to_s.ljust(width[i], ' ')
      if i == cols - 1
        puts
      else
        print ' | '
      end
    end
  end
end

desc 'Statistics about database'
task 'db:stats' => 'environment' do

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

desc 'Rebuild indexes'
task 'db:rebuild_indexes' => 'environment' do
  if Import::backup_tables_count > 0
    raise "Backup from a previous import exists. Drop them before running this job with rake import:remove_backup, or move them to another schema."
  end

  Discourse.enable_readonly_mode

  backup_schema = Jobs::Importer::BACKUP_SCHEMA
  table_names = DB.query_single("select table_name from information_schema.tables where table_schema = 'public'")

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
      index_definitions[table_name] = DB.query_single("SELECT indexdef FROM pg_indexes WHERE tablename = '#{table_name}' and schemaname = 'public';")
    end

    # Drop the new tables
    table_names.each do |table_name|
      DB.exec("DROP TABLE public.#{table_name}")
    end

    # Move the old tables back to the public schema
    table_names.each do |table_name|
      DB.exec("ALTER TABLE #{backup_schema}.#{table_name} SET SCHEMA public")
    end

    # Drop their indexes
    index_names = DB.query_single("SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('#{table_names.join("', '")}')")
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
  rescue
    # Can we roll this back?
    raise
  ensure
    Discourse.disable_readonly_mode
  end
end
