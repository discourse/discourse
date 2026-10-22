# frozen_string_literal: true

require "digest"
require "json"

module PluginGem
  def self.load(path, name, version, opts = nil)
    opts ||= {}

    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"

    spec_path = gems_path + "/specifications"

    spec_file = spec_path + "/#{name}-#{version}"

    if platform_variants(spec_file).find(&File.method(:exist?)).blank?
      command =
        "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies --no-user-install"
      command += " --source #{opts[:source]}" if opts[:source]
      puts command

      Bundler.with_unbundled_env { puts `#{command}` }
    end

    spec_file_variant = platform_variants(spec_file).find(&File.method(:exist?))
    if spec_file_variant.present?
      Gem.path << gems_path
      Gem::Specification.load(spec_file_variant).activate

      require opts[:require_name] ? opts[:require_name] : name unless opts[:require] == false
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      puts "Looked for: \n- #{platform_variants(spec_file).join("\n- ")}"
      exit(-1)
    end
  end

  GEMS_DIR = File.expand_path("../vendor/plugin-gems", __dir__)
  LOCKFILE = File.join(GEMS_DIR, "Gemfile.lock")
  # Gems for a plugin's standalone tooling, never needed at boot.
  TOOLING_GROUPS = %i[development test]
  # Checksums cover a gem server, and a path is the plugin's own code. A git
  # gem keeps its version across commits, so a lock can't pin it, and a
  # bundler plugin's source isn't verified at all.
  GEMFILE_SOURCES = [Bundler::Source::Rubygems, Bundler::Source::Path, Bundler::Source::Gemspec]

  # Resolves the Gemfiles of all plugins with `gemfile: true` in one bundle,
  # with every gem pinned to the application's version or a plugin's
  # Gemfile.lock, and activates the result. Nothing is required, plugins do
  # that themselves.
  def self.activate_gemfiles(plugins)
    gemfiles =
      plugins.filter_map do |plugin|
        next unless plugin.metadata.gemfile
        unless File.exist?(File.join(plugin.directory, "Gemfile.lock"))
          raise "Plugin #{plugin.directory_name} has a Gemfile but no Gemfile.lock; run `bundle lock` in #{plugin.directory} and commit it"
        end

        File.join(plugin.directory, "Gemfile")
      end
    return if gemfiles.empty?

    manifest = File.join(GEMS_DIR, "activate.json")
    cached = JSON.parse(File.read(manifest)) if File.exist?(manifest)
    specs = cached["specs"] if cached&.dig("key") == manifest_key(gemfiles)
    unless specs&.all? { |path, _directory| File.exist?(path) }
      specs = in_child_process { install(gemfiles) }
      File.write("#{manifest}.#{Process.pid}", JSON.generate(key: manifest_key(gemfiles), specs:))
      File.rename("#{manifest}.#{Process.pid}", manifest)
    end
    specs.each do |path, directory|
      spec = Gem::Specification.load(path)
      spec.full_gem_path = directory
      spec.activate
    end
  end

  # Even with nothing to do, bundler takes ~150 ms to find that out. The
  # active application specs and file contents decide whether the last
  # result still holds, including when enabled bundle groups change.
  def self.manifest_key(gemfiles)
    files = [Bundler.default_lockfile, *gemfiles.flat_map { [it, "#{it}.lock"] }, LOCKFILE]
    app_specs = Bundler.load.specs.map { [it.full_name, it.full_gem_path] }.sort
    Digest::SHA1.hexdigest(
      [
        RUBY_VERSION,
        app_specs,
        *files.map { |file| File.exist?(file) ? File.read(file) : "" },
      ].join("\0"),
    )
  end

  # Returns [gemspec path, source directory] pairs to activate, dependencies first.
  def self.install(gemfiles)
    # name => [version, directory of a git or path gem]. Taken before
    # resolving, which retags the application's spec objects with its sources.
    pins =
      Bundler.load.specs.to_h do |spec|
        directory = spec.full_gem_path if spec.source.is_a?(Bundler::Source::Path)
        [spec.name, [spec.version, directory]]
      end
    pins.delete("bundler")
    app_lock = Bundler.definition.locked_gems
    dependencies = plugin_dependencies(Bundler::Dsl.new, gemfiles)
    locks = gemfiles.to_h { [it, ensure_lock_matches(it)] }
    locks.each { |gemfile, lock| ensure_app_remotes(gemfile, lock, app_lock) }
    locked = locked_versions(dependencies, pins, locks)

    # Installed gems first: they are enough after most changes, and offline.
    attempts = [{ local: true }, {}]
    attempts.each_with_index do |options, index|
      return resolve(gemfiles, pins, locked, [app_lock, *locks.values], options)
    rescue Bundler::BundlerError => e
      if index == attempts.size - 1
        raise resolve_error(e, dependencies.values.flatten + lock_pins(locked), pins)
      end
    end
  rescue Bundler::BundlerError => e
    raise "Resolving plugin gems failed: #{e.message}"
  end

  # Bundler's frozen-mode check; it compares the two files without resolving,
  # and fails for a gem without a checksum once the lock has CHECKSUMS. A
  # lock's path gems are relative to its own bundle's root, and its checksum
  # errors name the lockfile bundler considers the default. Returns the
  # parsed lock.
  def self.ensure_lock_matches(gemfile)
    dir = File.dirname(gemfile)
    bundle_env = ENV.values_at("BUNDLE_GEMFILE", "BUNDLE_LOCKFILE")
    ENV["BUNDLE_GEMFILE"], ENV["BUNDLE_LOCKFILE"] = gemfile, "#{gemfile}.lock"
    Bundler.reset_paths!
    Bundler
      .settings
      .temporary(frozen: true) do
        definition = Bundler::Definition.build(gemfile, "#{gemfile}.lock", nil)
        definition.ensure_equivalent_gemfile_and_lockfile(true)
        unless definition.locked_checksums
          raise "Plugin #{File.basename(dir)}'s Gemfile.lock has no checksums; run `bundle lock --add-checksums` in #{dir} and commit it"
        end
        definition.locked_gems
      end
  rescue Bundler::ProductionError => e
    raise "Plugin #{File.basename(dir)}'s Gemfile.lock does not match its Gemfile; run `bundle lock` in #{dir} and commit it\n#{e.message}"
  ensure
    ENV["BUNDLE_GEMFILE"], ENV["BUNDLE_LOCKFILE"] = bundle_env
    Bundler.reset_paths!
  end

  # A plugin's gem servers are the application's. Its lock lists them, and
  # bundler's frozen check already made the lock match the Gemfile.
  def self.ensure_app_remotes(gemfile, lock, app_lock)
    remotes = app_lock.sources.grep(Bundler::Source::Rubygems).flat_map(&:remotes)
    foreign = lock.sources.grep(Bundler::Source::Rubygems).flat_map(&:remotes) - remotes
    return if foreign.empty?

    raise "Plugin #{File.basename(File.dirname(gemfile))}'s Gemfile uses the gem source #{foreign.join(", ")}; a plugin's gems must come from the application's gem sources (#{remotes.join(", ")})"
  end

  def self.plugin_dependencies(dsl, gemfiles)
    # Nested declarations use their top-level Gemfile's lock.
    gemfiles.to_h do |gemfile|
      dsl.eval_gemfile(gemfile)
      # Taken out, so that the next Gemfile may require the same gem with
      # another range; the resolver intersects them.
      dependencies = dsl.dependencies.slice!(0..)
      dependencies.each do |dependency|
        next if dependency.source.nil? || GEMFILE_SOURCES.include?(dependency.source.class)

        raise "Plugin #{dependency.gemfile.dirname.basename}'s Gemfile declares #{dependency.name} from #{dependency.source.class.name.demodulize.downcase}; a plugin's gems must come from the application's gem sources or a path"
      end
      dependencies.select! do |dependency|
        dependency.should_include? && (dependency.groups - TOOLING_GROUPS).any?
      end
      [gemfile, dependencies]
    end
  end

  def self.resolve(gemfiles, pins, locked, locks, options)
    dsl = Bundler::Dsl.new
    dependencies = plugin_dependencies(dsl, gemfiles).values.flatten
    dependencies.each do |dependency|
      version, _lockfile = locked[dependency.name]
      dependency.requirement.concat(["= #{version}"]) if version
    end
    # The rest of the locked gems are pinned on their own.
    dsl.dependencies.concat(lock_pins(locked.except(*dependencies.map(&:name))))
    pins.each do |name, (version, directory)|
      # A git or path gem has no release to pin to; its directory is its source.
      if directory
        dsl.path(directory) { dsl.gem(name) }
      else
        dsl.dependencies << Bundler::Dependency.new(name, "= #{version}")
      end
    end
    # Pins last: bundler takes a gem's source from the last dependency naming
    # it, so a plugin's path gem can't stand in for one of the application's.
    dsl.dependencies.unshift(*dependencies)

    # This process only exists to install the plugins' bundle, so the
    # application's memoized paths, gem home and bundle settings go.
    Bundler.reset_paths!
    Bundler
      .settings
      .temporary(
        path: GEMS_DIR,
        frozen: false,
        deployment: false,
        only: nil,
        with: nil,
        without: nil,
      ) do
        Bundler.configure_gem_home_and_path(Bundler.bundle_path)
        # Bundler.setup limits the known gems to the application's bundle.
        Dir["#{Bundler.bundle_path}/specifications/*.gemspec"].each do |path|
          Gem::Specification.add_spec(Gem::Specification.load(path))
        end

        definition = dsl.to_definition(LOCKFILE, {})
        # The locks' checksums, taken over as bundler does with its own lock:
        # a downloaded gem with another checksum fails the install. The
        # application's gems are never downloaded, its lock gives them their
        # entries in LOCKFILE.
        locks
          .flat_map(&:sources)
          .each do |locked_source|
            definition
              .sources
              .rubygems_sources
              .find { it == locked_source }
              &.checksum_store
              &.merge!(locked_source.checksum_store)
          end
        Bundler::Installer.install(Bundler.root, definition, options)

        specs =
          definition.specs.filter_map do |spec|
            [spec.loaded_from, spec.full_gem_path] unless Gem.loaded_specs.key?(spec.name)
          end
        puts "Resolved #{specs.size} plugin gems from #{gemfiles.size} Gemfiles"
        specs
      end
  end

  # Bundler names one side of a conflict between top-level requirements, and
  # all of the plugins' and the application's gems are top-level here.
  def self.resolve_error(error, dependencies, pins)
    names =
      (pins.keys + dependencies.map(&:name)).uniq.select do |name|
        error.message.match?(/'#{Regexp.escape(name)}[ ']/)
      end
    sides =
      dependencies
        .select { names.include?(it.name) }
        .map { "#{it.name} (#{it.requirement}) in #{it.gemfile}" }
    sides += names.filter_map { "#{it} (#{pins[it][0]}) in the application" if pins[it] }
    ["Resolving plugin gems failed: #{error.message}", *sides].join("\n")
  end

  # A plugin's Gemfile.lock pins every gem the application doesn't have, so
  # identical inputs install identical versions. The highest version any
  # plugin locks wins, so a plugin that never updates its lock doesn't hold
  # back the others. Only gems reachable from a Gemfile's boot dependencies
  # count; the rest of a lock is the plugin's tooling or stale.
  # Returns name => [version, lockfile].
  def self.locked_versions(dependencies, pins, locks)
    dependencies.each_with_object({}) do |(gemfile, gemfile_dependencies), versions|
      lockfile = "#{gemfile}.lock"
      specs = locks.fetch(gemfile).specs.group_by(&:name)
      names = gemfile_dependencies.map(&:name)
      force_ruby = gemfile_dependencies.select(&:force_ruby_platform).map(&:name)
      # The application's gems bring their own dependencies.
      names.each do |name|
        next if pins.key?(name) || !specs.key?(name)

        variants =
          Bundler::MatchPlatform.select_best_platform_match(
            specs[name],
            Bundler.local_platform,
            force_ruby: force_ruby.include?(name),
          )
        next if variants.empty?

        variants.each { |spec| names.concat(spec.dependencies.map(&:name) - names) }
        version = variants.first.version
        versions[name] = [version, lockfile] if versions[name].nil? || version > versions[name][0]
      end
    end
  end

  # Attributed to the lock that set the version, for resolve_error.
  def self.lock_pins(locked)
    locked.map do |name, (version, lockfile)|
      Bundler::Dependency.new(name, "= #{version}", "gemfile" => Pathname.new(lockfile))
    end
  end

  # Resolving tags the running bundle's spec objects with the resolver's
  # source: the shared stubs, and the full gemspecs they memoize on first
  # use, which also sit in the global spec load cache. Through those the
  # whole remote index (~200 MB) stays alive. A child process keeps all of
  # that out of the application. exit! skips at_exit hooks and finalizers,
  # so inherited sockets are left alone.
  def self.in_child_process
    reader, writer = IO.pipe
    pid =
      fork do
        reader.close
        result =
          begin
            { "value" => yield }
          rescue Exception => e
            { "error" => e.message }
          end
        writer.write(JSON.generate(result))
        $stdout.flush
      ensure
        exit!(0)
      end
    writer.close
    output = reader.read
    Process.wait(pid)
    raise "Resolving plugin gems failed, the child process died" if output.empty?

    result = JSON.parse(output)
    raise result["error"] if result["error"]

    result["value"]
  ensure
    reader&.close
  end

  def self.platform_variants(spec_file)
    platform_less = "#{spec_file}.gemspec"
    platform_full = "#{spec_file}-#{RUBY_PLATFORM}.gemspec"
    platform_version_less =
      "#{spec_file}-#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}.gemspec"

    variants = [platform_less, platform_full, platform_version_less]
    variants << "#{spec_file}-#{RUBY_PLATFORM}-gnu.gemspec" if RUBY_PLATFORM.end_with?("-linux")

    variants.uniq
  end
end
