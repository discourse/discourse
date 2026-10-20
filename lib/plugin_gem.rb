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

  # Resolves the Gemfiles of all plugins with `gemfile: true` in one bundle,
  # with every gem the application already loaded pinned to its version, and
  # activates the result. Nothing is required, plugins do that themselves.
  def self.activate_gemfiles(plugins)
    gemfiles =
      plugins.filter_map do |plugin|
        File.join(plugin.directory, "Gemfile") if plugin.metadata.gemfile
      end
    return if gemfiles.empty?

    manifest = File.join(GEMS_DIR, "activate.json")
    cached = JSON.parse(File.read(manifest)) if File.exist?(manifest)
    gemspecs = cached["gemspecs"] if cached&.dig("key") == manifest_key(gemfiles)
    unless gemspecs&.all? { |path| File.exist?(path) }
      gemspecs = in_child_process { install(gemfiles) }
      File.write(
        "#{manifest}.#{Process.pid}",
        JSON.generate(key: manifest_key(gemfiles), gemspecs:),
      )
      File.rename("#{manifest}.#{Process.pid}", manifest)
    end
    gemspecs.each { |path| Gem::Specification.load(path).activate }
  end

  # Even with nothing to do, bundler takes ~150 ms to find that out. Every
  # input bundler would compare is a file, so their contents decide whether
  # the last result still holds.
  def self.manifest_key(gemfiles)
    files = [Bundler.default_lockfile, *gemfiles.flat_map { [it, "#{it}.lock"] }, LOCKFILE]
    Digest::SHA1.hexdigest(
      [RUBY_VERSION, *files.map { |file| File.exist?(file) ? File.read(file) : "" }].join("\0"),
    )
  end

  # Returns the gemspec paths to activate, dependencies first.
  def self.install(gemfiles)
    # name => [version, directory of a git or path gem]. Taken before
    # resolving, which retags the application's spec objects with its sources.
    pins =
      Bundler.load.specs.to_h do |spec|
        directory = spec.full_gem_path if spec.source.is_a?(Bundler::Source::Path)
        [spec.name, [spec.version, directory]]
      end
    pins.delete("bundler")
    dependencies = plugin_dependencies(Bundler::Dsl.new, gemfiles)
    locked = lock_bounds(dependencies, pins)

    # Installed gems first: they are enough after most changes, and offline.
    attempts = [{ local: true }, {}].map { [locked, it] }
    attempts << [{}, {}] if locked.any?
    attempts.each_with_index do |(versions, options), index|
      if versions.empty? && locked.any?
        puts "The plugins' Gemfile.lock versions could not be kept, resolving without them"
      end
      return resolve(gemfiles, pins, versions, options)
    rescue Bundler::BundlerError => e
      raise resolve_error(e, dependencies, pins) if index == attempts.size - 1
    end
  rescue Bundler::BundlerError => e
    raise "Resolving plugin gems failed: #{e.message}"
  end

  def self.plugin_dependencies(dsl, gemfiles)
    dependencies =
      gemfiles.flat_map do |gemfile|
        dsl.eval_gemfile(gemfile)
        # Taken out, so that the next Gemfile may require the same gem with
        # another range; the resolver intersects them.
        dsl.dependencies.slice!(0..)
      end
    dependencies.reject { |dependency| (dependency.groups - TOOLING_GROUPS).empty? }
  end

  def self.resolve(gemfiles, pins, locked, options)
    dsl = Bundler::Dsl.new
    dependencies = plugin_dependencies(dsl, gemfiles)
    dependencies.each do |dependency|
      version = locked[dependency.name]
      dependency.requirement.concat(["= #{version}"]) if version
    end
    pins.each do |name, (version, directory)|
      # A git or path gem has no release to pin to; its directory is its source.
      if directory
        dsl.path(directory) { dsl.gem(name) }
      else
        dsl.dependencies << Bundler::Dependency.new(name, "= #{version}")
      end
    end
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
        # The application's gems come from their install directories, there
        # is no package to checksum.
        lockfile_checksums: false,
      ) do
        Bundler.configure_gem_home_and_path(Bundler.bundle_path)
        # Bundler.setup limits the known gems to the application's bundle.
        Dir["#{Bundler.bundle_path}/specifications/*.gemspec"].each do |path|
          Gem::Specification.add_spec(Gem::Specification.load(path))
        end

        definition = dsl.to_definition(LOCKFILE, {})
        Bundler::Installer.install(Bundler.root, definition, options)

        paths =
          definition.specs.filter_map do |spec|
            spec.loaded_from unless Gem.loaded_specs.key?(spec.name)
          end
        puts "Resolved #{paths.size} plugin gems from #{gemfiles.size} Gemfiles"
        paths
      end
  end

  # Bundler names one side of a conflict between top-level requirements, and
  # all of the plugins' and the application's gems are top-level here.
  def self.resolve_error(error, dependencies, pins)
    names =
      (pins.keys + dependencies.map(&:name)).uniq.select { error.message.include?("'#{it} (") }
    sides =
      dependencies
        .select { names.include?(it.name) }
        .map { "#{it.name} (#{it.requirement}) in #{it.gemfile}" }
    sides += names.filter_map { "#{it} (#{pins[it][0]}) in the application" if pins[it] }
    ["Resolving plugin gems failed: #{error.message}", *sides].join("\n")
  end

  # A plugin's Gemfile.lock records versions it was known to work with. The
  # highest of them pins a gem the plugins depend on directly, so a plugin
  # that never updates its lock doesn't hold back the others. The
  # application's gems are pinned anyway.
  def self.lock_bounds(dependencies, pins)
    dependencies
      .group_by(&:gemfile)
      .each_with_object({}) do |(gemfile, gemfile_dependencies), bounds|
        lockfile = "#{gemfile}.lock"
        next unless File.exist?(lockfile)

        locked = Bundler::LockfileParser.new(Bundler.read_file(lockfile)).specs.index_by(&:name)
        gemfile_dependencies.each do |dependency|
          version = locked[dependency.name]&.version
          next if version.nil? || pins.key?(dependency.name)

          bounds[dependency.name] = [bounds[dependency.name], version].compact.max
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
