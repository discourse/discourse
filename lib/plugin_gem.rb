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
  # The source types a plugin Gemfile may use. A gem from a gem server is
  # checked against the checksum in the lock. A path gem is code the plugin
  # ships itself. Git gems are refused: a gem keeps its version number from
  # commit to commit, so the lock check in `resolve` can't tell two commits
  # apart, and there is no checksum for a checkout. Sources added by bundler
  # plugins are refused because nothing checks what they download.
  GEMFILE_SOURCES = [Bundler::Source::Rubygems, Bundler::Source::Path, Bundler::Source::Gemspec]

  # Resolves the Gemfiles of all plugins with `# gemfile: true` together, as
  # one bundle. A gem the application already has keeps the application's
  # version. Every other gem gets the version from a plugin's Gemfile.lock.
  # The resolved gems are activated, not required; each plugin requires its
  # own gems.
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

    # A Gemfile or gemspec is Ruby code, and its result can change between
    # boots. So the bundle is resolved on every boot, and that happens in a
    # child process, see in_child_process.
    in_child_process { install(gemfiles) }.each do |gemspec, path, directory|
      spec = Gem::Specification.from_yaml(gemspec)
      spec.loaded_from = path
      spec.full_gem_path = directory
      spec.activate
    end
  end

  # Returns the resolved specs as YAML, each with its gemspec path and
  # install directory. Dependencies come before the gems that need them,
  # because activating a gem needs its dependencies activated first.
  def self.install(gemfiles)
    # The application's gems: name => [version, directory of a path or git
    # gem (else nil), full name, install directory]. Read before resolving,
    # because resolving overwrites the source of these spec objects.
    pins =
      Bundler.load.specs.to_h do |spec|
        directory = spec.full_gem_path if spec.source.is_a?(Bundler::Source::Path)
        [spec.name, [spec.version, directory, spec.full_name, spec.full_gem_path]]
      end
    pins.delete("bundler")
    app_lock = Bundler.definition.locked_gems
    app_groups = Bundler.definition.requested_dependencies.flat_map(&:groups).uniq
    app_groups -= Bundler.settings[:without]
    app_groups &= Bundler.settings[:only] if Bundler.settings[:only].any?
    dsl = Bundler::Dsl.new
    dependencies = plugin_dependencies(dsl, gemfiles, app_groups)
    locks = gemfiles.to_h { [it, ensure_lock_matches(it)] }
    locks.each { |gemfile, lock| ensure_app_remotes(gemfile, lock, app_lock) }
    locked = locked_versions(dependencies, pins, locks, app_lock)

    dependencies = dependencies.values.flatten
    dependencies.each do |dependency|
      version = locked[dependency.name]
      dependency.requirement.concat(["= #{version}"]) if version
    end
    # Locked gems that no plugin Gemfile names directly (dependencies of
    # dependencies) are added as pinned dependencies.
    locked
      .except(*dependencies.map(&:name), *pins.keys)
      .each { |name, version| dsl.dependencies << Bundler::Dependency.new(name, "= #{version}") }
    pins.each do |name, (version, directory)|
      next unless locked.key?(name)
      # A path or git gem of the application has no version on a gem server.
      # It is pinned to its directory instead.
      if directory
        dsl.path(directory) { dsl.gem(name) }
      else
        dsl.dependencies << Bundler::Dependency.new(name, "= #{version}")
      end
    end
    # The application's pins go last. Bundler takes a gem's source from the
    # last dependency with that name, so a plugin can't replace an
    # application gem with a path gem of the same name.
    dsl.dependencies.unshift(*dependencies)

    # First try with the installed gems only. That works offline and is enough
    # unless a lock changed. Only then ask the gem servers.
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

  # Runs bundler's frozen-mode check on the plugin's Gemfile and
  # Gemfile.lock. It compares the two files without resolving anything and
  # raises when they don't match. When the lock has a CHECKSUMS section, it
  # also raises for a gem without a checksum. BUNDLE_GEMFILE and
  # BUNDLE_LOCKFILE point at the plugin's files for the duration, because
  # bundler reads path gems relative to the Gemfile's directory and names
  # its default lockfile in error messages. Returns the parsed lock.
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
        if !definition.locked_checksums
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

  # A plugin may only use the application's gem servers. The servers are
  # read from the plugin's lock; ensure_lock_matches already made sure the
  # lock matches the Gemfile.
  def self.ensure_app_remotes(gemfile, lock, app_lock)
    remotes = app_lock.sources.grep(Bundler::Source::Rubygems).flat_map(&:remotes)
    foreign = lock.sources.grep(Bundler::Source::Rubygems).flat_map(&:remotes) - remotes
    return if foreign.empty?

    raise "Plugin #{File.basename(File.dirname(gemfile))}'s Gemfile uses the gem source #{foreign.join(", ")}; a plugin's gems must come from the application's gem sources (#{remotes.join(", ")})"
  end

  def self.plugin_dependencies(dsl, gemfiles, app_groups)
    # A Gemfile can eval_gemfile other files. Their gems count for the lock
    # of the plugin's top-level Gemfile.
    gemfiles.to_h do |gemfile|
      dsl.eval_gemfile(gemfile)
      # The dependencies are removed from the DSL before the next Gemfile is
      # evaluated. Bundler's `gem` raises when a Gemfile names a gem twice
      # with different requirements. Across plugins that is fine: the
      # resolver takes the intersection of the requirements.
      dependencies = dsl.dependencies.slice!(0..)
      dependencies.each do |dependency|
        next if dependency.source.nil? || GEMFILE_SOURCES.include?(dependency.source.class)

        raise "Plugin #{dependency.gemfile.dirname.basename}'s Gemfile declares #{dependency.name} from #{dependency.source.class.name.demodulize.downcase}; a plugin's gems must come from the application's gem sources or a path"
      end
      dependencies.select! do |dependency|
        dependency.should_include? && dependency.groups.intersect?(app_groups)
      end
      [gemfile, dependencies]
    end
  end

  def self.resolve(dsl, pins, locked, locks, app_lock, options)
    # This runs in the child process. Bundler has memoized the application's
    # paths, gem home and settings; they are replaced with the plugin
    # bundle's.
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
        # Bundler.setup has limited rubygems to the application's gems. The
        # gems already installed in GEMS_DIR are added back so bundler finds
        # them.
        Dir["#{Bundler.bundle_path}/specifications/*.gemspec"].each do |path|
          Gem::Specification.add_spec(Gem::Specification.load(path))
        end

        definition = dsl.to_definition(LOCKFILE, {})
        # Copy the checksums from the locks into the sources of this
        # definition, as bundler does with its own lockfile. A downloaded gem
        # with a different checksum fails the install. The application's
        # lock is included so its gems get their entries in LOCKFILE; they
        # are never downloaded. A Gemfile can scope a source to some gems
        # (`source "..." do ... end`). Bundler then has two source objects
        # for the same server, which compare equal, and both may install
        # gems, so both get the checksums.
        [app_lock, *locks].flat_map(&:sources)
          .each do |locked_source|
            definition
              .sources
              .rubygems_sources
              .select { it == locked_source }
              .each { it.checksum_store.merge!(locked_source.checksum_store) }
          end
        definition.setup_domain!(options)
        # Check every resolved spec before anything is installed.
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
        # When every gem is installed already, only the lockfile is written.
        # The installer would reload the application's gemspecs for nothing.
        if specs.all? { it.is_a?(Bundler::StubSpecification) && !it.installation_missing? }
          Bundler.create_bundle_path
          definition.lock
        else
          # Building a native extension runs ruby in a subprocess. It inherits
          # the environment, and with RUBYOPT and BUNDLE_GEMFILE still set it
          # would set up the application's bundle in GEM_HOME, which now
          # points at the plugin gem directory.
          Bundler.unbundle_env!
          Bundler::Installer.install(Bundler.root, definition, options)
        end

        # Return the checked specs to the application process as YAML. The
        # application must neither evaluate gemspecs again nor receive
        # bundler's source indexes.
        specs.map do |spec|
          metadata = spec.for_cache
          # A spec fetched from a gem server's compact index is an instance
          # of a bundler subclass. Its YAML carries that class name, and
          # Gem::Specification.from_yaml in the application only accepts
          # Gem::Specification. The gemspec installed with the gem is a plain
          # Gem::Specification, so that one is used instead.
          unless metadata.instance_of?(Gem::Specification)
            metadata = Gem::Specification.load(spec.loaded_from).for_cache
          end
          [metadata.to_yaml, spec.loaded_from, spec.full_gem_path]
        end
      end
  end

  # Decides the version of every gem the plugin Gemfiles need and returns
  # name => version.
  # - A gem in the application's lock gets the application's version. That
  #   also holds for gems in a group the application doesn't load.
  # - Every other gem gets its version from the plugin locks, dependencies
  #   of dependencies included. When several plugins lock a gem, the highest
  #   version wins. So a plugin with an old lock doesn't hold the others
  #   back.
  # - Only gems reachable from the plugins' dependencies are included. Other
  #   entries in a lock are development tooling or stale.
  def self.locked_versions(dependencies, pins, locks, app_lock)
    app_specs = app_lock.specs.group_by(&:name)
    dependencies.each_with_object({}) do |(gemfile, gemfile_dependencies), versions|
      specs = locks.fetch(gemfile).specs.group_by(&:name).merge(app_specs)
      names = gemfile_dependencies.map(&:name)
      force_ruby = gemfile_dependencies.select(&:force_ruby_platform).map(&:name)
      names.each do |name|
        # An application gem keeps its version. Its dependencies are followed
        # so they get pinned too.
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

  # Resolving runs in a child process. Bundler sets its source on the spec
  # objects of the running bundle, and that source holds the remote gem
  # index (about 200 MB). In the application process this memory would
  # never be freed. The child ends with exit!, which skips at_exit hooks and
  # finalizers. Those would act on sockets inherited from the application.
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
