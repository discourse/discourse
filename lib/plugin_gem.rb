# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

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

  # Resolves a plugin's gem requirements (ranges allowed) with bundler against
  # the running bundle, instead of installing exact versions with
  # --ignore-dependencies. Every gem of the running bundle stays at its locked
  # version, because it is already activated by the time plugins load. Only
  # the gems the bundle lacks, transitive dependencies included, are installed
  # into the plugin's gem path and activated. The result is cached in
  # gems/<ruby>/resolved-<digest>.json, keyed on the requirements, the
  # bundle's spec list and the plugin's lockfile.
  def self.resolve(path, requirements, lockfile: File.join(File.dirname(path), "Gemfile.lock"))
    requirements = requirements.transform_keys(&:to_s)
    plugin = File.basename(File.dirname(path))
    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"
    bundle_specs = bundle_specs_by_name
    unpinnable = unpinnable_bundle_gems
    activated = activated_plugin_gems(bundle_specs, unpinnable)
    refuse_locked_conflicts(plugin, bundle_specs, activated, unpinnable, requirements)
    # What an earlier plugin activated is a pin like the bundle's gems: one
    # version per process.
    bundle_specs = bundle_specs.merge(activated)
    digest =
      Digest::SHA1.hexdigest(
        requirements.sort.inspect + bundle_specs.map { |n, v| "#{n}-#{v}" }.sort.join(",") +
          (File.exist?(lockfile) ? File.read(lockfile) : ""),
      )
    # One manifest per bundle and lock: the same plugin checkout can serve
    # several application checkouts, each with its own locked versions, and an
    # updated lock must not reuse the old resolution.
    manifest_path = "#{gems_path}/resolved-#{digest[0, 12]}.json"

    manifest = read_manifest(manifest_path)
    if manifest.nil? || manifest["digest"] != digest
      # Several processes can boot a fresh checkout at once (turbo_rspec, two
      # dev servers); only one of them may resolve and install, the others
      # find the manifest once they get the lock.
      with_resolve_lock(gems_path) do
        manifest = read_manifest(manifest_path)
        if manifest.nil? || manifest["digest"] != digest
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          new_gems =
            locked_gems(plugin, lockfile, bundle_specs, unpinnable, requirements) ||
              resolve_with_bundler(plugin, bundle_specs, unpinnable, requirements)
          install_resolved(gems_path, new_gems)
          manifest = { "digest" => digest, "gems" => new_gems }
          write_manifest(manifest_path, manifest)
          seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
          puts "Resolved #{new_gems.size} gems for #{plugin} in #{seconds}s"
        end
      end
    end

    activate_resolved(gems_path, manifest["gems"])
  end

  # The requirements of a plugin's Gemfile, for `resolve`: the Gemfile is
  # evaluated with bundler's own DSL, so it takes everything a Gemfile takes.
  # Dependencies only in the `without` groups are skipped. A path gem is the
  # plugin's own code and is not a requirement itself; its gemspec's runtime
  # dependencies are. Dependencies bundler itself would skip (another
  # platform, `install_if`) are skipped.
  def self.gemfile_requirements(gemfile, without: %i[development test])
    dsl = Bundler::Dsl.new
    dsl.eval_gemfile(gemfile)
    dependencies =
      dsl.dependencies.reject do |dependency|
        (dependency.groups - without).empty? || !dependency.should_include?
      end
    dependencies.each do |dependency|
      if dependency.source.is_a?(Bundler::Source::Git)
        raise "#{dependency.name} comes from git in #{gemfile}; the resolver installs from rubygems.org only"
      end
      next unless dependency.source.is_a?(Bundler::Source::Rubygems)

      remote = dependency.source.remotes.map(&:to_s).find { |uri| uri != "https://rubygems.org/" }
      if remote
        raise "#{dependency.name} comes from #{remote} in #{gemfile}; the resolver installs from rubygems.org only"
      end
    end
    path_gems, gems =
      dependencies.partition { |dependency| dependency.source.is_a?(Bundler::Source::Path) }
    own_names = path_gems.map(&:name)

    requirements = gems.to_h { |dependency| [dependency.name, dependency.requirement.as_list] }
    path_gems.each do |dependency|
      spec = dependency.source.specs.find { |candidate| candidate.name == dependency.name }
      raise "No gemspec for #{dependency.name} at #{dependency.source.path}" if spec.nil?

      spec.runtime_dependencies.each do |runtime|
        next if own_names.include?(runtime.name)

        merged = (requirements[runtime.name] || []) | runtime.requirement.as_list
        merged.delete(">= 0") if merged.size > 1
        requirements[runtime.name] = merged
      end
    end
    requirements
  end

  # A manifest that does not parse is treated as missing, so a broken file
  # costs one resolve instead of every boot.
  def self.read_manifest(manifest_path)
    return nil unless File.exist?(manifest_path)

    JSON.parse(File.read(manifest_path))
  rescue JSON::ParserError
    nil
  end

  # Written to a temp file and renamed, so a concurrent reader never sees a
  # partial manifest.
  def self.write_manifest(manifest_path, manifest)
    tmp_path = "#{manifest_path}.#{Process.pid}.tmp"
    File.write(tmp_path, JSON.pretty_generate(manifest))
    File.rename(tmp_path, manifest_path)
  end

  def self.with_resolve_lock(gems_path)
    FileUtils.mkdir_p(gems_path)
    File.open("#{gems_path}/resolve.lock", File::CREAT | File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    end
  end

  # A plugin can carry a Gemfile with its own gems and the Gemfile.lock that
  # `bundle lock` writes for it, next to plugin.rb. Then the versions come from
  # that lock, automated lock updates and `bundle update` keep it current,
  # and bundler only runs at boot when the lock no longer fits the
  # requirements. The plugin's lock is resolved on its own, not against the
  # application, so gems the application's bundle already has are dropped
  # from it (the application's version is activated already) and a dependency
  # of a locked gem that the application's version cannot satisfy makes the
  # lock unusable.
  def self.locked_gems(plugin, lockfile, bundle_specs, unpinnable, requirements)
    return nil unless File.exist?(lockfile)

    specs = local_platform_specs(Bundler::LockfileParser.new(File.read(lockfile)).specs)
    in_bundle = ->(name) { bundle_specs.key?(name) || unpinnable.key?(name) }

    problems = []
    replaced = []
    gems = {}
    requirements.each_key do |name|
      if (locked = bundle_specs[name]) && (in_lock = specs[name]) && in_lock.version.to_s != locked
        replaced << "#{plugin}: #{name} #{in_lock.version} in Gemfile.lock is #{locked} in the application"
      end
    end
    queue = requirements.keys.reject(&in_bundle)
    until queue.empty?
      name = queue.shift
      next if gems.key?(name)

      spec = specs[name]
      if spec.nil?
        problems << "#{name} is not in Gemfile.lock"
        next
      end
      if (requirement = requirements[name]) &&
           !Gem::Requirement.new(requirement).satisfied_by?(spec.version)
        problems << "#{name} #{spec.version} does not satisfy #{requirement_text(requirement)}"
      end

      dependencies = []
      spec.dependencies.each do |dependency|
        if (locked = bundle_specs[dependency.name])
          unless dependency.requirement.satisfied_by?(Gem::Version.new(locked))
            problems << "#{name} #{spec.version} needs #{dependency.name} #{dependency.requirement}, " \
              "but the application locks #{dependency.name} #{locked}"
          end
          # The plugin's own bundle may have resolved a different version of
          # a gem the application has; at runtime it gets the application's.
          # Worth a line, so a plugin developed against the newer one is not
          # surprised later.
          if (in_lock = specs[dependency.name]) && in_lock.version.to_s != locked
            replaced << "#{plugin}: #{dependency.name} #{in_lock.version} in Gemfile.lock is #{locked} in the application"
          end
        elsif !unpinnable.key?(dependency.name)
          dependencies << dependency.name
          queue << dependency.name
        end
      end
      gems[name] = {
        "name" => name,
        "version" => spec.version.to_s,
        "dependencies" => dependencies,
      }
    end

    if problems.any?
      puts "#{plugin}: Gemfile.lock ignored: #{problems.uniq.join(", ")}"
      return nil
    end

    replaced.uniq.each { |line| puts line }

    gems.values
  end

  # A lock for several platforms lists a gem once per platform, and the
  # entries can differ in their dependencies (a precompiled build needs no
  # build helper). Bundler's own platform matching picks the entry it would
  # install here. Returns name => spec.
  def self.local_platform_specs(specs)
    specs
      .group_by(&:name)
      .transform_values do |candidates|
        Bundler::MatchPlatform.select_best_platform_match(
          candidates,
          Bundler.local_platform,
        ).first || candidates.first
      end
  end

  # The gems of the running bundle that come from a gem source, name =>
  # locked version. These are the pins for bundler. Bundler itself is never
  # a pin: pinning it would make `bundle lock` refuse to run under any other
  # installed bundler version.
  def self.bundle_specs_by_name
    Bundler
      .load
      .specs
      .reject do |spec|
        unpinnable_source?(spec.source) || spec.source.is_a?(Bundler::Source::Metadata)
      end
      .to_h { |spec| [spec.name, spec.version.to_s] }
  end

  # Gems that are activated but not in the bundle, name => version: what the
  # plugins loaded before this one brought in, and default gems the
  # application loaded. Bundler is left out for the reason given at
  # bundle_specs_by_name.
  def self.activated_plugin_gems(bundle_specs, unpinnable)
    Gem
      .loaded_specs
      .each_with_object({}) do |(name, spec), gems|
        next if name == "bundler" || bundle_specs.key?(name) || unpinnable.key?(name)
        gems[name] = spec.version.to_s
      end
  end

  # The gems of the running bundle that come from git or a path, name =>
  # "git" or "path". They have no version on rubygems to pin them to, so a
  # plugin cannot require them through the resolver; it already has them,
  # since the application activated them at boot.
  def self.unpinnable_bundle_gems
    Bundler
      .load
      .specs
      .select { |spec| unpinnable_source?(spec.source) }
      .to_h { |spec| [spec.name, spec.source.is_a?(Bundler::Source::Git) ? "git" : "path"] }
  end

  def self.unpinnable_source?(source)
    source.is_a?(Bundler::Source::Path) || source.is_a?(Bundler::Source::Git)
  end

  # Checked before the lock and the cache, so a conflict is never hidden by a
  # Gemfile.lock that skips the gems the application already has.
  def self.refuse_locked_conflicts(plugin, bundle_specs, activated, unpinnable, requirements)
    requirements.each do |name, requirement|
      if (active = activated[name]) &&
           !Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new(active))
        raise "Plugin #{plugin} needs #{name} #{requirement_text(requirement)}, " \
                "but #{name} #{active} is already activated"
      end

      if (source = unpinnable[name])
        raise "Plugin #{plugin} needs #{name} #{requirement_text(requirement)}, but the application loads #{name} from #{source}; " \
                "drop the requirement, the gem is already activated"
      end

      next unless (locked = bundle_specs[name])
      next if Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new(locked))

      raise "Plugin #{plugin} needs #{name} #{requirement_text(requirement)}, " \
              "but the application locks #{name} #{locked}"
    end
  end

  # A requirement is a string or, for two bounds, an array of strings.
  def self.requirement_text(requirement)
    Array(requirement).join(", ")
  end

  def self.resolve_with_bundler(plugin, bundle_specs, unpinnable, requirements)
    Dir.mktmpdir("plugin-gems") do |dir|
      gemfile = +"source \"https://rubygems.org\"\n"
      # A gem the plugin also requires is pinned too: refuse_locked_conflicts
      # checked that the locked version satisfies it, and that version is the
      # one activated at runtime, so nothing may resolve against a newer one.
      bundle_specs.each { |name, version| gemfile << "gem #{name.inspect}, \"= #{version}\"\n" }
      requirements.each do |name, requirement|
        next if bundle_specs.key?(name)

        gemfile << "gem #{name.inspect}, #{Array(requirement).map(&:inspect).join(", ")}\n"
      end
      File.write("#{dir}/Gemfile", gemfile)

      output = nil
      status = nil
      Bundler.with_unbundled_env do
        output, status = Open3.capture2e({ "BUNDLE_GEMFILE" => "#{dir}/Gemfile" }, "bundle", "lock")
      end
      raise "Resolving gems for #{plugin} failed:\n#{output}" unless status.success?

      parsed = Bundler::LockfileParser.new(File.read("#{dir}/Gemfile.lock"))
      # The application's git and path gems are activated already; the
      # rubygems.org release bundler resolved for them must not be added.
      new_specs =
        local_platform_specs(
          parsed.specs.reject { |spec| bundle_specs.key?(spec.name) || unpinnable.key?(spec.name) },
        )
      new_names = new_specs.keys.to_set
      new_specs.values.map do |spec|
        {
          "name" => spec.name,
          "version" => spec.version.to_s,
          "dependencies" => spec.dependencies.map(&:name).select { |dep| new_names.include?(dep) },
        }
      end
    end
  end

  def self.install_resolved(gems_path, gems)
    gems.each do |gem|
      spec_file = "#{gems_path}/specifications/#{gem["name"]}-#{gem["version"]}"
      next if platform_variants(spec_file).any? { |variant| File.exist?(variant) }

      command = %W[
        gem
        install
        #{gem["name"]}
        -v
        #{gem["version"]}
        -i
        #{gems_path}
        --no-document
        --ignore-dependencies
        --no-user-install
      ]
      puts command.join(" ")
      output, status = Bundler.with_unbundled_env { Open3.capture2e(*command) }
      puts output
      unless status.success?
        raise "Installing plugin gem #{gem["name"]} #{gem["version"]} failed, see the output above"
      end
    end
  end

  # Dependencies first, so `activate` finds them in Gem.loaded_specs.
  def self.activate_resolved(gems_path, gems)
    Gem.path << gems_path if Gem.path.exclude?(gems_path)
    remaining = gems.dup
    activated = Set.new
    until remaining.empty?
      ready = remaining.select { |gem| gem["dependencies"].all? { |dep| activated.include?(dep) } }
      raise "Circular plugin gem dependencies: #{remaining.map { |g| g["name"] }}" if ready.empty?

      ready.each do |gem|
        spec_file = "#{gems_path}/specifications/#{gem["name"]}-#{gem["version"]}"
        variant = platform_variants(spec_file).find { |candidate| File.exist?(candidate) }
        raise "Resolved plugin gem #{gem["name"]} #{gem["version"]} is not installed" unless variant

        Gem::Specification.load(variant).activate
        activated << gem["name"]
      end
      remaining -= ready
    end
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
