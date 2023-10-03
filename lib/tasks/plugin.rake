# frozen_string_literal: true

directory "plugins"

desc "install all official plugins (use GIT_WRITE=1 to pull with write access)"
task "plugin:install_all_official" do
  skip = Set.new(%w[customer-flair poll])

  STDERR.puts "Allowing write to all repos!" if ENV["GIT_WRITE"]

  Plugin::Metadata::OFFICIAL_PLUGINS.each do |name|
    next if skip.include? name
    repo = "https://github.com/discourse/#{name}"
    dir = repo.split("/").last
    path = File.expand_path("plugins/" + dir)

    if Dir.exist? path
      STDERR.puts "Skipping #{dir} cause it already exists!"
      next
    end

    if ENV["GIT_WRITE"]
      repo = repo.gsub("https://github.com/", "git@github.com:")
      repo += ".git"
    end

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

desc "install plugin"
task "plugin:install", :repo do |t, args|
  repo = ENV["REPO"] || ENV["repo"] || args[:repo]
  name = ENV["NAME"] || ENV["name"] || File.basename(repo, ".git")

  plugin_path = File.expand_path("plugins/" + name)
  if File.directory?(File.expand_path(plugin_path))
    abort("Plugin directory, " + plugin_path + ", already exists.")
  end

  clone_status = system("git clone " + repo + " " + plugin_path)
  unless clone_status
    FileUtils.rm_rf(plugin_path)
    abort("Unable to clone plugin")
  end
end

desc "update all plugins"
task "plugin:update_all" do |t|
  # Loop through each directory
  plugins = Dir.glob(File.expand_path("plugins/*")).select { |f| File.directory? f }
  # run plugin:update
  plugins.each do |plugin|
    next unless File.directory?(plugin + "/.git")
    Rake::Task["plugin:update"].invoke(plugin)
    Rake::Task["plugin:update"].reenable
  end
  Rake::Task["plugin:versions"].invoke
end

desc "update a plugin"
task "plugin:update", :plugin do |t, args|
  plugin = ENV["PLUGIN"] || ENV["plugin"] || args[:plugin]
  plugin_path = plugin
  plugin = File.basename(plugin)

  unless File.directory?(plugin_path)
    if File.directory?("plugins/" + plugin)
      plugin_path = File.expand_path("plugins/" + plugin)
    else
      abort("Plugin " + plugin + " not found")
    end
  end

  `git -C '#{plugin_path}' fetch origin --tags --force`

  upstream_branch =
    `git -C '#{plugin_path}' for-each-ref --format='%(upstream:short)' $(git -C '#{plugin_path}' symbolic-ref -q HEAD)`.strip
  has_origin_main = `git -C '#{plugin_path}' branch -a`.match?(%r{remotes/origin/main\z})
  has_local_main = `git -C '#{plugin_path}' show-ref refs/heads/main`.present?

  if upstream_branch == "origin/master" && has_origin_main
    puts "Branch has changed to `origin/main`"

    if has_local_main
      update_status = system("git -C '#{plugin_path}' checkout main")
      abort("Unable to pull latest version of plugin #{plugin_path}") unless update_status
    else
      `git -C '#{plugin_path}' branch -m master main`
    end

    `git -C '#{plugin_path}' branch -u origin/main main`
  end

  update_status = system("git -C '#{plugin_path}' pull --no-rebase")
  abort("Unable to pull latest version of plugin #{plugin_path}") unless update_status
end

desc "pull compatible plugin versions for all plugins"
task "plugin:pull_compatible_all" do |t|
  STDERR.puts <<~TEXT if GlobalSetting.load_plugins?
      WARNING: Plugins were activated before running `rake plugin:pull_compatible_all`
        You should prefix this command with LOAD_PLUGINS=0
    TEXT

  # Loop through each directory
  plugins = Dir.glob(File.expand_path("plugins/*")).select { |f| File.directory? f }
  # run plugin:pull_compatible
  plugins.each do |plugin|
    next unless File.directory?(plugin + "/.git")
    Rake::Task["plugin:pull_compatible"].invoke(plugin)
    Rake::Task["plugin:pull_compatible"].reenable
  end
end

desc "pull a compatible plugin version"
task "plugin:pull_compatible", :plugin do |t, args|
  plugin = ENV["PLUGIN"] || ENV["plugin"] || args[:plugin]
  plugin_path = plugin
  plugin = File.basename(plugin)

  unless File.directory?(plugin_path)
    if File.directory?("plugins/" + plugin)
      plugin_path = File.expand_path("plugins/" + plugin)
    else
      abort("Plugin " + plugin + " not found")
    end
  end

  checkout_version = Discourse.find_compatible_git_resource(plugin_path)

  # Checkout value of the version compat
  if checkout_version
    puts "checking out compatible #{plugin} version: #{checkout_version}"
    update_status =
      system(
        "git -C '#{plugin_path}' cat-file -e #{checkout_version} || git -C '#{plugin_path}' fetch --depth 1 $(git -C '#{plugin_path}' rev-parse --symbolic-full-name @{upstream} | awk -F '/' '{print $3}') #{checkout_version}; git -C '#{plugin_path}' reset --hard #{checkout_version}",
      )
    abort("Unable to checkout a compatible plugin version") unless update_status
  else
    puts "#{plugin} is already at latest compatible version"
  end
end

desc "install all plugin gems"
task "plugin:install_all_gems" do |t|
  # Left intentionally blank.
  # When the app is being loaded, all missing gems are installed
  # See: lib/plugin_gem.rb
  puts "Done"
end

desc "install plugin gems"
task "plugin:install_gems", :plugin do |t, args|
  # Left intentionally blank.
  # When the app is being loaded, all missing gems are installed
  # See: lib/plugin_gem.rb
  puts "Done"
end

def spec(plugin, parallel: false, argv: nil)
  params = []
  params << "--profile" if !parallel
  params << "--fail-fast" if ENV["RSPEC_FAILFAST"]
  params << "--seed #{ENV["RSPEC_SEED"]}" if Integer(ENV["RSPEC_SEED"], exception: false)
  params << argv if argv

  # reject system specs as they are slow and need dedicated setup
  files =
    Dir.glob("./plugins/#{plugin}/spec/**/*_spec.rb").reject { |f| f.include?("spec/system/") }.sort

  if files.length > 0
    cmd = parallel ? "bin/turbo_rspec" : "bin/rspec"

    Rake::FileUtilsExt.verbose(!parallel) do
      sh("LOAD_PLUGINS=1 #{cmd} #{files.join(" ")} #{params.join(" ")}")
    end
  else
    abort "No specs found."
  end
end

desc "run plugin specs"
task "plugin:spec", %i[plugin argv] do |_, args|
  args.with_defaults(plugin: "*")
  spec(args[:plugin], argv: args[:argv])
end

desc "run plugin specs in parallel"
task "plugin:turbo_spec", %i[plugin argv] do |_, args|
  args.with_defaults(plugin: "*")
  spec(args[:plugin], parallel: true, argv: args[:argv])
end

desc "run plugin qunit tests"
task "plugin:qunit", %i[plugin timeout] do |t, args|
  args.with_defaults(plugin: "*")

  rake = "#{Rails.root}/bin/rake"

  cmd = "LOAD_PLUGINS=1 "

  target =
    if args[:plugin] == "*"
      puts "Running qunit tests for all plugins"
      "plugins"
    else
      puts "Running qunit tests for #{args[:plugin]}"
      args[:plugin]
    end

  cmd += "TARGET='#{target}' "

  cmd += "#{rake} qunit:test"
  cmd += "[#{args[:timeout]}]" if args[:timeout]

  system cmd
  exit $?.exitstatus
end

desc "run all migrations of a plugin"
namespace "plugin:migrate" do
  def list_migrations(plugin_name)
    plugin_root = File.join(Rails.root, "plugins", plugin_name)
    migrations_root = File.join(plugin_root, "db", "{post_migrate,migrate}", "*.rb")
    Dir[migrations_root]
      .map { |migration_filename| File.basename(migration_filename)[/(^.*?)_/, 1].to_i }
      .sort
  end

  def cmd(operation, migration_number)
    "rails db:migrate:#{operation} LOAD_PLUGINS=1 VERSION=#{migration_number}"
  end

  task :down, [:plugin] do |t, args|
    list_migrations(args[:plugin]).reverse.each do |migration_number|
      sh cmd(:down, migration_number)
    end
  end

  task :up, [:plugin] do |t, args|
    list_migrations(args[:plugin]).each { |migration_number| sh cmd(:up, migration_number) }
  end
end

desc "display all plugin versions"
task "plugin:versions" do |t, args|
  versions =
    Dir
      .glob("*", base: "plugins")
      .map { |plugin| [plugin, "plugins/#{plugin}", "plugins/#{plugin}/.git"] }
      .select do |plugin, plugin_dir, plugin_git_dir|
        File.directory?(plugin_dir) && File.exist?(plugin_git_dir)
      end
      .sort_by { |plugin, _, _| plugin }
      .map do |plugin, _, plugin_git_dir|
        version = `git --git-dir \"#{plugin_git_dir}\" rev-parse HEAD`
        abort("unable to get #{plugin} version") unless version
        [plugin, version.strip[0...8]]
      end
      .to_h

  puts JSON.pretty_generate(versions)
end
