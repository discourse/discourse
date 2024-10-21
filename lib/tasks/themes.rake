# frozen_string_literal: true

require "yaml"

#
# 2 different formats are accepted:
#
# == JSON format
#
# bin/rake themes:install -- '--{"discourse-something": "https://github.com/discourse/discourse-something"}'
# OR
# bin/rake themes:install -- '--{"discourse-something": {"url": "https://github.com/discourse/discourse-something", default: true}}'
#
# == YAML file formats
#
# theme_name: https://github.com/example/theme.git
# OR
# theme_name:
#   url: https://github.com/example/theme_name.git
#   branch: "master"
#   private_key: ""
#   default: false
#   add_to_all_themes: false  # only for components - install on every theme
#
# In the first form, only the url is required.
#
desc "Install themes & theme components"
task "themes:install" => :environment do |task, args|
  theme_args = (STDIN.tty?) ? "" : STDIN.read
  use_json = theme_args == ""

  theme_args =
    begin
      use_json ? JSON.parse(ARGV.last.gsub("--", "")) : YAML.safe_load(theme_args)
    rescue StandardError
      puts use_json ? "Invalid JSON input. \n#{ARGV.last}" : "Invalid YML: \n#{theme_args}"
      exit 1
    end

  log, counts = ThemesInstallTask.install(theme_args)

  puts log

  puts
  puts "Results:"
  puts " Installed: #{counts[:installed]}"
  puts " Updated:   #{counts[:updated]}"
  puts " Errors:    #{counts[:errors]}"
  puts " Skipped:   #{counts[:skipped]}"

  exit 1 if counts[:errors] > 0
end

# env THEME_ARCHIVE - path to the archive
# env UPDATE_COMPONENTS - 0 to skip updating components
desc "Install themes & theme components from an archive"
task "themes:install:archive" => :environment do |task, args|
  filename = ENV["THEME_ARCHIVE"]
  update_components = ENV["UPDATE_COMPONENTS"] == "0" ? "none" : nil
  RemoteTheme.update_zipped_theme(filename, File.basename(filename), update_components:)
end

def update_themes(version_cache: Concurrent::Map.new)
  Theme
    .includes(:remote_theme)
    .where(enabled: true, auto_update: true)
    .find_each do |theme|
      begin
        theme.transaction do
          remote_theme = theme.remote_theme
          next if remote_theme.blank? || remote_theme.remote_url.blank?
          prefix = "[db:#{RailsMultisite::ConnectionManagement.current_db}] '#{theme.name}' - "
          puts "#{prefix} checking..."

          cache_key =
            "#{remote_theme.remote_url}:#{remote_theme.branch}:#{Digest::SHA256.hexdigest(remote_theme.private_key.to_s)}"

          if version_cache[cache_key] == remote_theme.remote_version && !remote_theme.out_of_date?
            puts "#{prefix} up to date (cached from previous lookup)"
            next
          end

          remote_theme.update_remote_version

          version_cache.put_if_absent(cache_key, remote_theme.remote_version)

          if remote_theme.out_of_date?
            puts "#{prefix} updating from #{remote_theme.local_version[0..7]} to #{remote_theme.remote_version[0..7]}"
            remote_theme.update_from_remote(already_in_transaction: true)
          else
            puts "#{prefix} up to date"
          end

          if remote_theme.last_error_text.present?
            raise RemoteTheme::ImportError.new(remote_theme.last_error_text)
          end
        end
      rescue => e
        $stderr.puts "[#{RailsMultisite::ConnectionManagement.current_db}] Failed to update '#{theme.name}' (#{theme.id}): #{e}"
        raise if ENV["RAISE_THEME_ERRORS"] == "1"
      end
    end

  true
end

desc "Update themes & theme components"
task "themes:update": %w[environment assets:precompile:theme_transpiler] do
  if ENV["RAILS_DB"].present?
    update_themes
  else
    version_cache = Concurrent::Map.new

    concurrency = ENV["THEME_UPDATE_CONCURRENCY"]&.to_i || 10
    puts "Updating themes with concurrency: #{concurrency}" if concurrency > 1

    Parallel.each(RailsMultisite::ConnectionManagement.all_dbs, in_threads: concurrency) do |db|
      RailsMultisite::ConnectionManagement.with_connection(db) { update_themes(version_cache:) }
    end
  end
end

desc "List all the installed themes on the site"
task "themes:audit" => :environment do
  components = Set.new
  puts "Selectable themes"
  puts "-----------------"

  Theme
    .where("(enabled OR user_selectable) AND NOT component")
    .each do |theme|
      puts theme.remote_theme&.remote_url || theme.name
      theme.child_themes.each do |child|
        if child.enabled
          repo = child.remote_theme&.remote_url || child.name
          components << repo
        end
      end
    end

  puts
  puts "Selectable components"
  puts "---------------------"
  components.each { |repo| puts repo }
end

desc "Run QUnit tests of a theme/component"
task "themes:qunit", :type, :value do |t, args|
  type = args[:type]
  value = args[:value]
  raise <<~TEXT if !%w[name url id ids].include?(type) || value.blank?
      Wrong arguments type:#{type.inspect}, value:#{value.inspect}"
      Usage:
        `bundle exec rake "themes:qunit[url,<theme_url>]"`
        OR
        `bundle exec rake "themes:qunit[name,<theme_name>]"`
        OR
        `bundle exec rake "themes:qunit[id,<theme_id>]"`
        OR
        `bundle exec rake "themes:qunit[ids,<theme_id|theme_id|theme_id>]
    TEXT

  ENV["THEME_#{type.upcase}"] = value.to_s
  ENV["QUNIT_RAILS_ENV"] ||= "development" # qunit:test will switch to `test` by default
  Rake::Task["qunit:test"].reenable
  Rake::Task["qunit:test"].invoke("/theme-qunit")
end

desc "Install a theme/component on a temporary DB and run QUnit tests"
task "themes:isolated_test" => :environment do |t, args|
  # This task can be called in a production environment that likely has a bunch
  # of DISCOURSE_* env vars that we don't want to be picked up by the Unicorn
  # server that will be spawned for the tests. So we need to unset them all
  # before we proceed.
  # Make this behavior opt-in to make it very obvious.
  if ENV["UNSET_DISCOURSE_ENV_VARS"] == "1"
    ENV.keys.each do |key|
      next if !key.start_with?("DISCOURSE_")
      next if ENV["DONT_UNSET_#{key}"] == "1"
      ENV[key] = nil
    end
  end

  redis = TemporaryRedis.new
  redis.start
  Discourse.redis = redis.instance
  db = TemporaryDb.new
  db.start
  db.migrate
  ActiveRecord::Base.establish_connection(
    adapter: "postgresql",
    database: "discourse",
    port: db.pg_port,
    host: "localhost",
  )

  seeded_themes = Theme.pluck(:id)
  Rake::Task["themes:install"].invoke
  themes = Theme.pluck(:name, :id)

  ENV["PGPORT"] = db.pg_port.to_s
  ENV["PGHOST"] = "localhost"
  ENV["QUNIT_RAILS_ENV"] = "development"
  ENV["DISCOURSE_DEV_DB"] = "discourse"
  ENV["DISCOURSE_REDIS_PORT"] = redis.port.to_s

  count = 0
  themes.each do |(name, id)|
    if seeded_themes.include?(id)
      puts "Skipping seeded theme #{name} (id: #{id})"
      next
    end
    puts "Running tests for theme #{name} (id: #{id})..."
    Rake::Task["themes:qunit"].reenable
    Rake::Task["themes:qunit"].invoke("id", id)
    count += 1
  end
  raise "Error: No themes were installed" if count == 0
ensure
  db&.stop
  db&.remove
  redis&.remove
end

desc "Clones all official themes"
task "themes:clone_all_official" do |task, args|
  require "theme_metadata"
  FileUtils.rm_rf("tmp/themes")

  official_themes =
    ThemeMetadata::OFFICIAL_THEMES.each do |theme_name|
      repo = "https://github.com/discourse/#{theme_name}"
      path = File.join(Rails.root, "tmp/themes/#{theme_name}")

      attempts = 0

      begin
        attempts += 1
        system("git clone #{repo} #{path}", exception: true)
      rescue StandardError
        abort("Failed to clone #{repo}") if attempts >= 3
        STDERR.puts "Failed to clone #{repo}... trying again..."
        retry
      end
    end
end

desc "pull compatible theme versions for all themes"
task "themes:pull_compatible_all" do |t|
  Dir
    .glob(File.expand_path("#{Rails.root}/tmp/themes/*"))
    .select { |f| File.directory? f }
    .each do |theme_path|
      next unless File.directory?(theme_path + "/.git")

      theme_name = File.basename(theme_path)
      checkout_version = Discourse.find_compatible_git_resource(theme_path)

      # Checkout value of the version compat
      if checkout_version
        puts "checking out compatible #{theme_name} version: #{checkout_version}"

        update_status =
          system(
            "git -C '#{theme_path}' cat-file -e #{checkout_version} || git -C '#{theme_path}' fetch --depth 1 $(git -C '#{theme_path}' rev-parse --symbolic-full-name @{upstream} | awk -F '/' '{print $3}') #{checkout_version}; git -C '#{theme_path}' reset --hard #{checkout_version}",
          )

        abort("Unable to checkout a compatible theme version") unless update_status
      else
        puts "#{theme_name} is already at latest compatible version"
      end
    end
end

# Note that this should only be used in CI where it is safe to mutate the database without rolling back since running
# the themes QUnit tests requires the themes to be installed in the database.
desc "Runs qunit tests for all official themes"
task "themes:qunit_all_official" => :environment do |task, args|
  theme_ids_with_qunit_tests = []

  ThemeMetadata::OFFICIAL_THEMES.each do |theme_name|
    path = File.join(Rails.root, "tmp/themes/#{theme_name}")

    if Dir.glob("#{File.join(path, "test")}/**/*.{js,es6}").any?
      theme = RemoteTheme.import_theme_from_directory(path)
      theme_ids_with_qunit_tests << theme.id
    else
      puts "Skipping #{theme_name} as no QUnit tests have been detected"
    end
  end

  Rake::Task["themes:qunit"].reenable
  Rake::Task["themes:qunit"].invoke("ids", theme_ids_with_qunit_tests.join("|"))
end
