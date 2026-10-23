# frozen_string_literal: true

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

    # Gemfiles and gemspecs can depend on arbitrary Ruby inputs. Reevaluate
    # them on every boot, using installed gems before trying remote sources.
    in_child_process { install(gemfiles) }.each do |gemspec, path, directory|
      spec = Gem::Specification.from_yaml(gemspec)
      spec.loaded_from = path
      spec.full_gem_path = directory
      spec.activate
    end
  end

  # Returns serialized specs and their locations, dependencies first.
  def self.install(gemfiles)
    # Capture core's versions and locations before resolution retags its specs.
    # name => [version, path source directory, full name, installed directory].
    pins =
      Bundler.load.specs.to_h do |spec|
        directory = spec.full_gem_path if spec.source.is_a?(Bundler::Source::Path)
        [spec.name, [spec.version, directory, spec.full_name, spec.full_gem_path]]
      end
    pins.delete("bundler")
    app_lock = Bundler.definition.locked_gems
    dsl = Bundler::Dsl.new
    dependencies = plugin_dependencies(dsl, gemfiles)
    locks = gemfiles.to_h { [it, ensure_lock_matches(it)] }
    locks.each { |gemfile, lock| ensure_app_remotes(gemfile, lock, app_lock) }
    locked = locked_versions(dependencies, pins, locks, app_lock)

    dependencies = dependencies.values.flatten
    dependencies.each do |dependency|
      version = locked[dependency.name]
      dependency.requirement.concat(["= #{version}"]) if version
    end
    # The rest of the locked gems are pinned on their own.
    locked
      .except(*dependencies.map(&:name), *pins.keys)
      .each { |name, version| dsl.dependencies << Bundler::Dependency.new(name, "= #{version}") }
    pins.each do |name, (version, directory)|
      next unless locked.key?(name)
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

    # Installed gems first: they are enough after most changes, and offline.
    [{ local: true }, {}].each do |options|
      specs = resolve(dsl, pins, locked, locks.values, app_lock, options)
      puts "Resolved #{specs.size} plugin gems from #{gemfiles.size} Gemfiles"
      return specs
    rescue Bundler::GemNotFound, Bundler::SolveFailure
      raise unless options[:local]
    end
  rescue Bundler::BundlerError => e
    raise "Resolving plugin gems failed for #{gemfiles.join(", ")}: #{e.message}"
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
    excluded_groups = %i[development]
    excluded_groups << :test unless Rails.env.test?
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
        dependency.should_include? && (dependency.groups - excluded_groups).any?
      end
      [gemfile, dependencies]
    end
  end

  def self.resolve(dsl, pins, locked, locks, app_lock, options)
    # This process only exists to install the plugins' bundle, so the
    # application's memoized paths, gem home and bundle settings go.
    Bundler.reset_paths!
    Bundler
      .settings
      .temporary(
        path: GEMS_DIR,
        frozen: false,
        deployment: false,
        disable_checksum_validation: false,
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
        # A source scoped to some gems is a second, equal object; every one
        # of them installs gems, so every one of them gets the checksums.
        [app_lock, *locks].flat_map(&:sources)
          .each do |locked_source|
            definition
              .sources
              .rubygems_sources
              .select { it == locked_source }
              .each { it.checksum_store.merge!(locked_source.checksum_store) }
          end
        definition.setup_domain!(options)
        # Check the complete graph before installing any gems.
        locked_specs =
          locks.flat_map(&:specs).group_by(&:name).merge(app_lock.specs.group_by(&:name))
        definition.specs.each do |spec|
          next if spec.name == "bundler"
          if pin = pins[spec.name]
            unless spec.full_name == pin[2] && spec.full_gem_path == pin[3]
              raise "Resolved plugin bundle would replace core gem #{pin[2]} with #{spec.full_name} from #{spec.source}"
            end
            next
          end
          if spec.source.is_a?(Bundler::Source::Path) && !File.file?(spec.loaded_from)
            raise "Plugin path gem #{spec.name} needs a .gemspec file in #{spec.source.path.expand_path(spec.source.root_path)}"
          end
          locked_spec =
            locked_specs
              .fetch(spec.name, [])
              .find do |candidate|
                candidate.full_name == spec.full_name && candidate.source == spec.source
              end
          unless locked.key?(spec.name) && locked_spec
            raise "Resolved plugin gem #{spec.full_name} is not in the committed Gemfile.lock files with the same source; update the locks for #{Bundler.local_platform} and commit them"
          end
          if spec.source.is_a?(Bundler::Source::Rubygems) &&
               !locked_spec.source.checksum_store.to_lock(locked_spec).match?(/(?: |,)sha256=/)
            raise "Locked gem #{spec.full_name} has no SHA256 checksum; run `bundle lock --add-checksums` and commit it"
          end
        end
        specs = definition.specs.reject { Gem.loaded_specs.key?(it.name) }
        # Running the installer on a warm boot needlessly reloads core's gemspecs.
        if specs.all? { it.is_a?(Bundler::StubSpecification) && !it.installation_missing? }
          Bundler.create_bundle_path
          definition.lock
        else
          # Extension builders must not boot core's bundle in the plugin gem directory.
          Bundler.unbundle_env!
          Bundler::Installer.install(Bundler.root, definition, options)
        end

        # Transfer the validated metadata, without reevaluating gemspecs or
        # retaining Bundler's source indexes in the application process.
        specs.map do |spec|
          metadata = spec.for_cache
          # A spec fetched from a compact index is a subclass, which the
          # application's safe YAML load refuses; its installed gemspec isn't.
          unless metadata.instance_of?(Gem::Specification)
            metadata = Gem::Specification.load(spec.loaded_from).for_cache
          end
          [metadata.to_yaml, spec.loaded_from, spec.full_gem_path]
        end
      end
  end

  # Core's lock takes precedence, even for gems outside its active groups.
  # Plugin locks pin the remaining gems, including transitive dependencies.
  # The highest version any plugin locks wins, so a plugin that never updates
  # its lock doesn't hold back the others. Only gems reachable from boot
  # dependencies count; the rest of a lock is the plugin's tooling or stale.
  # Returns name => version.
  def self.locked_versions(dependencies, pins, locks, app_lock)
    app_specs = app_lock.specs.group_by(&:name)
    dependencies.each_with_object({}) do |(gemfile, gemfile_dependencies), versions|
      specs = locks.fetch(gemfile).specs.group_by(&:name).merge(app_specs)
      names = gemfile_dependencies.map(&:name)
      force_ruby = gemfile_dependencies.select(&:force_ruby_platform).map(&:name)
      names.each do |name|
        # Only core gems reachable from plugin dependencies need resolving.
        if pin = pins[name]
          versions[name] = pin[0]
          variants = specs.fetch(name, []).select { it.full_name == pin[2] }
          names.concat(variants.flat_map { it.dependencies.map(&:name) } - names)
          next
        end
        raise "Plugin dependency #{name} is missing from #{gemfile}.lock" unless specs.key?(name)

        variants =
          Bundler::MatchPlatform.select_best_platform_match(
            specs[name],
            Bundler.local_platform,
            force_ruby: force_ruby.include?(name),
          )
        if variants.empty?
          raise "Plugin #{File.basename(File.dirname(gemfile))}'s Gemfile.lock has no compatible platform for #{name}; run `bundle lock --add-platform #{Bundler.local_platform}` and commit it"
        end

        variants.each { |spec| names.concat(spec.dependencies.map(&:name) - names) }
        version = variants.first.version
        versions[name] = version if versions[name].nil? || version > versions[name]
      end
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
