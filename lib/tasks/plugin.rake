# frozen_string_literal: true

directory 'plugins'

desc 'install all official plugins (use GIT_WRITE=1 to pull with write access)'
task 'plugin:install_all_official' do
  skip = Set.new([
    'customer-flair',
    'discourse-nginx-performance-report',
    'lazy-yt',
    'poll'
  ])

  map = {
    'Canned Replies' => 'https://github.com/discourse/discourse-canned-replies',
    'discourse-perspective' => 'https://github.com/discourse/discourse-perspective-api'
  }

  STDERR.puts "Allowing write to all repos!" if ENV['GIT_WRITE']

  Plugin::Metadata::OFFICIAL_PLUGINS.each do |name|
    next if skip.include? name
    repo = map[name] || "https://github.com/discourse/#{name}"
    dir = repo.split('/').last
    path = File.expand_path('plugins/' + dir)

    if Dir.exist? path
      STDERR.puts "Skipping #{dir} cause it already exists!"
      next
    end

    if ENV['GIT_WRITE']
      repo = repo.gsub("https://github.com/", "git@github.com:")
      repo += ".git"
    end

    status = system("git clone #{repo} #{path}")
    unless status
      abort("Failed to clone #{repo}")
    end
  end
end

desc 'install plugin'
task 'plugin:install', :repo do |t, args|
  repo = ENV['REPO'] || ENV['repo'] || args[:repo]
  name = ENV['NAME'] || ENV['name'] || File.basename(repo, '.git')

  plugin_path = File.expand_path('plugins/' + name)
  if File.directory?(File.expand_path(plugin_path))
    abort('Plugin directory, ' + plugin_path + ', already exists.')
  end

  clone_status = system('git clone ' + repo + ' ' + plugin_path)
  unless clone_status
    FileUtils.rm_rf(plugin_path)
    abort('Unable to clone plugin')
  end
end

desc 'update all plugins'
task 'plugin:update_all' do |t|
  # Loop through each directory
  plugins = Dir.glob(File.expand_path('plugins/*')).select { |f| File.directory? f }
  # run plugin:update
  plugins.each do |plugin|
    next unless File.directory?(plugin + "/.git")
    Rake::Task['plugin:update'].invoke(plugin)
    Rake::Task['plugin:update'].reenable
  end
end

desc 'update a plugin'
task 'plugin:update', :plugin do |t, args|
  plugin = ENV['PLUGIN'] || ENV['plugin'] || args[:plugin]
  plugin_path = plugin
  plugin = File.basename(plugin)

  unless File.directory?(plugin_path)
    if File.directory?('plugins/' + plugin)
      plugin_path = File.expand_path('plugins/' + plugin)
    else
      abort('Plugin ' + plugin + ' not found')
    end
  end

  update_status = system('git --git-dir "' + plugin_path + '/.git" --work-tree "' + plugin_path + '" pull')
  abort('Unable to pull latest version of plugin') unless update_status
end

desc 'install all plugin gems'
task 'plugin:install_all_gems' do |t|
  plugins = Dir.glob(File.expand_path('plugins/*')).select { |f| File.directory? f }
  plugins.each do |plugin|
    Rake::Task['plugin:install_gems'].invoke(plugin)
    Rake::Task['plugin:install_gems'].reenable
  end
end

desc 'install plugin gems'
task 'plugin:install_gems', :plugin do |t, args|
  plugin = ENV['PLUGIN'] || ENV['plugin'] || args[:plugin]
  plugin_path = plugin + "/plugin.rb"

  if File.file?(plugin_path)
    File.open(plugin_path).each do |l|
      next if !l.start_with? "gem"
      next unless /gem\s['"](.*)['"],\s['"](.*)['"]/.match(l)
      puts "gem install #{$1} -v #{$2} -i #{plugin}/gems/#{RUBY_VERSION} --no-document --ignore-dependencies --no-user-install"
      system("gem install #{$1} -v #{$2} -i #{plugin}/gems/#{RUBY_VERSION} --no-document --ignore-dependencies --no-user-install")
    end
  end
end

desc 'run plugin specs'
task 'plugin:spec', :plugin do |t, args|
  args.with_defaults(plugin: "*")
  params = ENV['RSPEC_FAILFAST'] ? '--profile --fail-fast' : '--profile'
  ruby = `which ruby`.strip
  files = Dir.glob("./plugins/#{args[:plugin]}/spec/**/*_spec.rb")
  if files.length > 0
    sh "LOAD_PLUGINS=1 #{ruby} -S rspec #{files.join(' ')} #{params}"
  else
    abort "No specs found."
  end
end

desc 'run plugin qunit tests'
task 'plugin:qunit', [:plugin, :timeout] do |t, args|
  args.with_defaults(plugin: "*")

  rake = `which rake`.strip

  cmd = 'LOAD_PLUGINS=1 '
  cmd += 'QUNIT_SKIP_CORE=1 '

  if args[:plugin] == "*"
    puts "Running qunit tests for all plugins"
  else
    puts "Running qunit tests for #{args[:plugin]}"
    cmd += "QUNIT_SINGLE_PLUGIN='#{args[:plugin]}' "
  end

  cmd += "#{rake} qunit:test"
  cmd += "[#{args[:timeout]}]" if args[:timeout]

  sh cmd
end
