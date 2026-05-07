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
desc "Export a theme bundle (theme + components + settings) as a zip"
task "themes:export_theme_bundle", %i[theme output] => :environment do |task, args|
  theme_arg = args[:theme] || ENV["THEME_ID"]
  output_path = args[:output] || ENV["OUTPUT"] || "/tmp/theme-bundle.zip"

  if theme_arg.blank?
    puts "Available themes:"
    puts "-----------------"
    Theme
      .where(component: false)
      .includes(:child_themes)
      .order(:name)
      .each do |t|
        components = t.child_themes.count
        puts "  [#{t.id}] #{t.name} (#{components} components)"
      end
    puts
    puts "Usage: rake \"themes:export_theme_bundle[<name_or_id>,/tmp/bundle.zip]\""
    exit 1
  end

  theme =
    if theme_arg.to_s =~ /\A\d+\z/
      Theme.where(component: false).find_by(id: theme_arg.to_i)
    else
      Theme.where(component: false).find_by("LOWER(name) = ?", theme_arg.downcase)
    end

  raise "Theme '#{theme_arg}' not found" unless theme

  components = theme.child_themes

  puts "Exporting '#{theme.name}' with #{components.count} components..."

  settings_count = 0

  Dir.mktmpdir("theme-bundle") do |tmpdir|
    # Export parent theme
    theme_exporter = ThemeStore::ZipExporter.new(theme)
    theme_exporter.with_export_dir do |theme_dir|
      FileUtils.cp_r(theme_dir, File.join(tmpdir, "theme"))
    end

    # Collect settings overrides for parent
    parent_settings = {}
    current = theme.cached_settings
    defaults = theme.cached_default_settings
    current.each do |name, value|
      next if name == "theme_uploads" || name == "theme_uploads_local"
      parent_settings[name] = value if value != defaults[name]
    end

    # Export each component
    manifest_components = []
    components_dir = File.join(tmpdir, "components")
    FileUtils.mkdir_p(components_dir)

    components.each do |comp|
      safe_name = "#{comp.id}-#{comp.name.downcase.gsub(/[^0-9a-z.\-]/, "-")}"
      puts "  Exporting component '#{comp.name}'..."

      comp_exporter = ThemeStore::ZipExporter.new(comp)
      comp_exporter.with_export_dir do |comp_dir|
        FileUtils.cp_r(comp_dir, File.join(components_dir, safe_name))
      end

      # Component settings overrides
      # Note: upload-type settings and objects-type settings with uploads in their schema
      # will not round-trip correctly. Upload IDs in the manifest won't exist on the
      # target instance, and the actual upload files are not included in the bundle.
      comp_settings = {}
      comp_current = comp.cached_settings
      comp_defaults = comp.cached_default_settings
      comp_current.each do |name, value|
        next if name == "theme_uploads" || name == "theme_uploads_local"
        comp_settings[name] = value if value != comp_defaults[name]
      end

      manifest_components << {
        "id" => comp.id,
        "name" => comp.name,
        "dir" => safe_name,
        "remote_url" => comp.remote_theme&.remote_url,
        "enabled" => comp.enabled?,
        "settings" => comp_settings,
      }
    end

    # Write manifest
    manifest = {
      "name" => theme.name,
      "theme_id" => theme.id,
      "exported_at" => Time.now.utc.iso8601,
      "settings" => parent_settings,
      "components" => manifest_components,
    }
    File.write(File.join(tmpdir, "manifest.json"), JSON.pretty_generate(manifest))

    # Package as zip
    FileUtils.rm_f(output_path)
    require "zip"
    Zip::File.open(output_path, create: true) do |zipfile|
      Dir[File.join(tmpdir, "**", "*")].each do |file|
        next if File.directory?(file)
        entry_name = file.sub("#{tmpdir}/", "")
        zipfile.add(entry_name, file)
      end
    end

    settings_count = parent_settings.size + manifest_components.sum { |c| c["settings"].size }
  end

  puts "Bundle exported to #{output_path}"
  puts "  Theme: #{theme.name}"
  puts "  Components: #{components.count}"
  puts "  Settings overrides: #{settings_count}"

  # Warn about upload-type settings that won't round-trip
  upload_settings =
    ThemeSetting
      .where(theme_id: [theme.id] + components.map(&:id), data_type: ThemeSetting.types[:upload])
      .where.not(value: nil)
  if upload_settings.any?
    puts "  WARNING: #{upload_settings.count} upload-type setting(s) detected. Upload files are not"
    puts "  included in the bundle and will need to be re-uploaded manually after import."
  end
end

desc "Import a theme bundle (theme + components + settings) from a zip"
task "themes:import_theme_bundle", %i[input] => :environment do |task, args|
  input_path = args[:input] || ENV["INPUT"]

  if input_path.blank? || !File.exist?(input_path)
    puts "Usage: rake \"themes:import_theme_bundle[/tmp/bundle.zip]\""
    exit 1
  end

  require "zip"

  Dir.mktmpdir("theme-bundle-import") do |tmpdir|
    Zip::File.open(input_path) do |zip_file|
      zip_file.each do |entry|
        dest = File.join(tmpdir, entry.name)
        dest = Pathname.new(dest).cleanpath.to_s
        unless dest.start_with?(File.join(tmpdir, ""))
          raise "Zip entry '#{entry.name}' attempts to escape extract directory"
        end

        if entry.directory?
          FileUtils.mkdir_p(dest)
        else
          FileUtils.mkdir_p(File.dirname(dest))
          IO.copy_stream(entry.get_input_stream, dest)
        end
      end
    end

    manifest_path = File.join(tmpdir, "manifest.json")
    raise "No manifest.json found in bundle" unless File.exist?(manifest_path)
    manifest = JSON.parse(File.read(manifest_path))

    puts "Importing '#{manifest["name"]}' with #{manifest["components"]&.length || 0} components..."

    if Theme.find_by(name: manifest["name"])
      puts "  WARNING: A theme named '#{manifest["name"]}' already exists. A duplicate will be created."
    end

    # Import components first
    imported_components = []
    (manifest["components"] || []).each do |comp|
      comp_dir = File.expand_path(File.join(tmpdir, "components", comp["dir"]))
      unless comp_dir.start_with?(File.join(tmpdir, "components", ""))
        raise "Invalid component directory in manifest: '#{comp["dir"]}'"
      end
      unless Dir.exist?(comp_dir)
        puts "  WARNING: Component directory '#{comp["dir"]}' not found, skipping"
        next
      end

      puts "  Importing component '#{comp["name"]}'..."
      imported = RemoteTheme.import_theme_from_directory(comp_dir)

      enabled = comp.fetch("enabled", true) != false
      imported.update!(enabled: enabled)
      status = enabled ? "" : " (disabled)"
      puts "  Imported component '#{comp["name"]}'#{status}"

      imported_components << imported

      (comp["settings"] || {}).each do |name, value|
        puts "    Setting #{name}..."
        imported.update_setting(name.to_sym, value)
      rescue Discourse::InvalidParameters
        puts "    WARNING: Setting '#{name}' not found, skipping"
      end
    end

    # Import the parent theme
    theme_dir = File.join(tmpdir, "theme")
    raise "No theme/ directory found in bundle" unless Dir.exist?(theme_dir)

    puts "  Importing theme '#{manifest["name"]}'..."
    imported_theme = RemoteTheme.import_theme_from_directory(theme_dir)

    # Wire up components
    imported_theme.child_themes = imported_components
    imported_components.each { |comp| puts "  Attached component '#{comp.name}'" }

    (manifest["settings"] || {}).each do |name, value|
      puts "  Setting #{name}..."
      imported_theme.update_setting(name.to_sym, value)
    rescue Discourse::InvalidParameters
      puts "  WARNING: Setting '#{name}' not found, skipping"
    end

    puts
    puts "Bundle imported successfully!"
    puts "  Theme: #{imported_theme.name} (id: #{imported_theme.id})"
    puts "  Components: #{imported_components.size}"
    puts "  Preview: /admin/customize/themes/#{imported_theme.id}"
  end
end

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
task "themes:update": %w[environment assets:precompile:asset_processor] do
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
  official_theme_ids_with_qunit_tests = []

  ThemeMetadata::OFFICIAL_THEMES.each do |theme_name|
    path = File.join(Rails.root, "tmp/themes/#{theme_name}")

    if Dir.glob("#{File.join(path, "test")}/**/*.{js,gjs}").any?
      theme = RemoteTheme.import_theme_from_directory(path)
      official_theme_ids_with_qunit_tests << theme.id
    else
      puts "Skipping #{theme_name} as no QUnit tests have been detected"
    end
  end

  core_theme_ids_with_qunit_tests = []

  Theme::CORE_THEMES.each do |(theme_name, theme_id)|
    path = File.join(Rails.root, "themes/#{theme_name}")

    if Dir.glob("#{File.join(path, "test")}/**/*.{js,gjs}").any?
      core_theme_ids_with_qunit_tests << theme_id
    else
      puts "Skipping #{theme_name} as no QUnit tests have been detected"
    end
  end

  Rake::Task["themes:qunit"].reenable
  Rake::Task["themes:qunit"].invoke("ids", official_theme_ids_with_qunit_tests.join("|"))

  ENV["EMBER_RAISE_ON_DEPRECATION"] = "1"
  Rake::Task["themes:qunit"].invoke("ids", core_theme_ids_with_qunit_tests.join("|"))
end
