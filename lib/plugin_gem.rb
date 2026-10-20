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
  # gems/<ruby>/resolved-<digest>.json, keyed on the requirements and the
  # bundle's spec list.
  def self.resolve(path, requirements, require: false)
    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"
    bundle_specs = bundle_specs_by_name
    refuse_locked_conflicts(bundle_specs, unpinnable_bundle_gems, requirements)
    digest =
      Digest::SHA1.hexdigest(
        requirements.sort.inspect + bundle_specs.map { |n, v| "#{n}-#{v}" }.sort.join(","),
      )
    # One manifest per bundle: the same plugin checkout can serve several
    # application checkouts, each with its own locked versions.
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
            locked_gems(path, bundle_specs, requirements) ||
              resolve_with_bundler(bundle_specs, requirements)
          install_resolved(gems_path, new_gems)
          manifest = { "digest" => digest, "gems" => new_gems }
          write_manifest(manifest_path, manifest)
          seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
          puts "Resolved #{new_gems.size} gems for #{File.basename(File.dirname(path))} in #{seconds}s"
        end
      end
    end

    activate_resolved(gems_path, manifest["gems"])
    requirements.each_key { |name| Kernel.require(name) } if require
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

  # A plugin may commit the resolution as `plugin-gems.lock` next to its
  # plugin.rb (the "gems" list of a manifest), the way an application
  # commits Gemfile.lock: then every install gets the same versions and
  # bundler only runs when the lock no longer fits. It is used when every
  # locked gem satisfies the requirement that names it and none of them
  # is in the application's bundle; otherwise it is ignored with a note
  # and bundler resolves afresh.
  def self.locked_gems(path, bundle_specs, requirements)
    lock_path = File.join(File.dirname(path), "plugin-gems.lock")
    return nil unless File.exist?(lock_path)

    gems = JSON.parse(File.read(lock_path))
    by_name = gems.to_h { |gem| [gem["name"], gem["version"]] }
    problems = []
    requirements.each do |name, requirement|
      next if bundle_specs.key?(name)
      if by_name[name].nil?
        problems << "#{name} is not in the lock"
      elsif !Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new(by_name[name]))
        problems << "#{name} #{by_name[name]} does not satisfy #{requirement}"
      end
    end
    gems.each do |gem|
      if bundle_specs.key?(gem["name"]) || unpinnable_bundle_gems.key?(gem["name"])
        problems << "#{gem["name"]} is in the application's bundle"
      end
    end

    if problems.any?
      puts "plugin-gems.lock ignored: #{problems.join(", ")}"
      return nil
    end

    gems
  end

  # The gems of the running bundle that come from a gem source, name =>
  # locked version. These are the pins for bundler.
  def self.bundle_specs_by_name
    Bundler
      .load
      .specs
      .reject { |spec| unpinnable_source?(spec.source) }
      .to_h { |spec| [spec.name, spec.version.to_s] }
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
  # plugin-gems.lock that skips the gems the application already has.
  def self.refuse_locked_conflicts(bundle_specs, unpinnable, requirements)
    requirements.each do |name, requirement|
      if (source = unpinnable[name])
        raise "Plugin needs #{name} #{requirement}, but the application loads #{name} from #{source}; " \
                "drop the requirement, the gem is already activated"
      end

      next unless (locked = bundle_specs[name])
      next if Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new(locked))

      raise "Plugin needs #{name} #{requirement}, but the application locks #{name} #{locked}"
    end
  end

  def self.resolve_with_bundler(bundle_specs, requirements)
    Dir.mktmpdir("plugin-gems") do |dir|
      gemfile = +"source \"https://rubygems.org\"\n"
      bundle_specs.each do |name, version|
        gemfile << "gem #{name.inspect}, \"= #{version}\"\n" unless requirements.key?(name)
      end
      requirements.each do |name, requirement|
        gemfile << "gem #{name.inspect}, #{requirement.inspect}\n"
      end
      File.write("#{dir}/Gemfile", gemfile)

      output = nil
      status = nil
      Bundler.with_unbundled_env do
        output, status = Open3.capture2e({ "BUNDLE_GEMFILE" => "#{dir}/Gemfile" }, "bundle", "lock")
      end
      raise "Resolving plugin gems failed:\n#{output}" unless status.success?

      parsed = Bundler::LockfileParser.new(File.read("#{dir}/Gemfile.lock"))
      new_specs = parsed.specs.reject { |spec| bundle_specs.key?(spec.name) }
      new_names = new_specs.map(&:name).to_set
      new_specs
        .uniq(&:name)
        .map do |spec|
          {
            "name" => spec.name,
            "version" => spec.version.to_s,
            "dependencies" =>
              spec.dependencies.map(&:name).select { |dep| new_names.include?(dep) },
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
