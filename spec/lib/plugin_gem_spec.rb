# frozen_string_literal: true

require "rubygems/package"

RSpec.describe PluginGem do
  let(:tmp_dir) { Dir.mktmpdir("plugin-gem-spec") }
  let(:repo) { File.join(tmp_dir, "repo") }
  let(:gems_dir) { File.join(tmp_dir, "plugin-gems") }
  let(:app_lockfile) { File.join(tmp_dir, "app", "Gemfile.lock") }
  let(:app_versions) { Bundler.load.specs.to_h { [it.name, it.version.to_s] } }
  let(:rack) { app_versions.fetch("rack") }
  let(:app_checksums) do
    File.read(Rails.root.join("Gemfile.lock")).scan(/^  (\S+) \([^)]+\) (sha256=\h+)$/).to_h
  end
  let!(:booted_specs) { Gem.loaded_specs.dup.merge(git_gem.name => git_gem) }
  let(:loaded_specs) { booted_specs.dup }
  let(:plugins) { [] }
  # Stands in for a gem the application loads from git: to bundler that is a
  # path source, a checkout with a gemspec, and only its directory matters.
  let(:git_gem) do
    dir = File.join(tmp_dir, "app", "delta")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "delta.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |spec|
        spec.name = "delta"
        spec.version = "1.0.0"
        spec.summary = "delta"
        spec.authors = ["test"]
      end
    GEMSPEC
    Bundler::Source::Path.new("path" => dir).specs.first
  end
  let(:repo_gems) do
    [
      ["alpha", "1.0.0", { "beta" => "~> 1.0", "rack" => ">= 1" }],
      ["alpha", "1.1.0", { "beta" => "~> 1.0", "rack" => ">= 1" }],
      %w[beta 1.0.0],
      %w[beta 1.1.0],
      ["gamma", "1.0.0", { git_gem.name => ">= 0" }],
      %w[delta 1.0.0],
      %w[shared 1.0.0],
      %w[shared 1.1.0],
      %w[foo 2.3.1],
      %w[foo 2.4.0],
      # Newer than anything the application has, so only a pin keeps them out.
      %w[rack 99.0.0],
    ]
  end

  def build_repo
    specs =
      repo_gems.map do |name, version, dependencies = {}, platform = "ruby"|
        Gem::Specification.new do |spec|
          spec.name = name
          spec.version = version
          spec.platform = platform
          spec.summary = name
          spec.authors = ["test"]
          dependencies.each do |dependency, requirement|
            spec.add_dependency(dependency, requirement)
          end
        end
      end
    FileUtils.mkdir_p(["#{repo}/gems", "#{repo}/quick/Marshal.4.8"])
    specs.each do |spec|
      Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
        Gem::Package.build(spec, true, false, "#{repo}/gems/#{spec.file_name}")
      end
      File.binwrite(
        "#{repo}/quick/Marshal.4.8/#{spec.full_name}.gemspec.rz",
        Gem.deflate(Marshal.dump(spec)),
      )
    end
    index = specs.map { |spec| [spec.name, spec.version, spec.platform.to_s] }
    File.binwrite("#{repo}/specs.4.8.gz", Gem::Util.gzip(Marshal.dump(index)))
  end

  # `lock` is name => version, written as `bundle lock` would with the
  # dependencies and checksums from the repo; nil writes no Gemfile.lock.
  # `path` adds path gems: name => [version, dependencies]. `checksums`
  # replaces checksums by name; nil writes no CHECKSUMS.
  def add_plugin(name, gemfile, lock:, opt_in: true, **options)
    dir = File.join(tmp_dir, "plugins", name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "plugin.rb"), "# name: #{name}\n# gemfile: #{opt_in}\n")
    write_plugin_files(dir, gemfile, lock, **options)
    plugins << Plugin::Instance.parse_from_source(File.join(dir, "plugin.rb"))
    dir
  end

  def write_plugin_files(
    dir,
    gemfile,
    lock,
    path: {},
    checksums: {},
    source: "https://rubygems.org"
  )
    File.write(File.join(dir, "Gemfile"), "source \"#{source}\"\n#{gemfile}")
    return if lock.nil?

    dsl = Bundler::Dsl.new
    dsl.eval_gemfile(File.join(dir, "Gemfile"))
    gems =
      lock.map do |name, version|
        [name, version, repo_gems.find { it[0] == name && it[1] == version }&.dig(2)]
      end
    # `bundle lock` would add the application's gems the plugin's gems need.
    app_gems = gems.flat_map { it[2]&.keys || [] }.uniq - lock.keys
    gems += app_gems.map { [it, app_versions.fetch(it), nil] }
    path_sections =
      path.map do |name, (version, dependencies)|
        "PATH\n  remote: #{name}\n  specs:\n#{lock_specs([[name, version, dependencies]])}\n\n"
      end
    File.write(File.join(dir, "Gemfile.lock"), <<~LOCK)
      #{path_sections.join}GEM
        remote: #{source}/
        specs:
      #{lock_specs(gems)}

      PLATFORMS
        ruby

      DEPENDENCIES
      #{dsl.dependencies.map(&:to_lock).sort.join("\n")}
      #{checksum_section(gems, path, checksums) if checksums}
    LOCK
  end

  def checksum_section(gems, path, checksums)
    lines =
      path.map { |name, (version)| "  #{name} (#{version})" } +
        gems.map do |name, version|
          "  #{name} (#{version}) #{checksums.fetch(name) { checksum(name, version) }}"
        end
    "\nCHECKSUMS\n#{lines.sort.join("\n")}\n"
  end

  def checksum(name, version)
    gem = "#{repo}/gems/#{name}-#{version}.gem"
    return "sha256=#{Digest::SHA256.file(gem).hexdigest}" if File.exist?(gem)

    # The application's path and git gems have none in its lock.
    app_checksums.fetch(name) { "sha256=#{Digest::SHA256.hexdigest(name)}" }
  end

  def lock_specs(gems)
    gems
      .flat_map do |name, version, dependencies|
        ["    #{name} (#{version})", *dependencies&.map { "      #{_1} (#{_2})" }]
      end
      .join("\n")
  end

  # A fresh process: only the application's gems are activated.
  def boot
    loaded_specs.replace(booted_specs)
    expect { PluginGem.activate_gemfiles(plugins) }
  end

  def installed
    Dir["#{gems_dir}/ruby/*/specifications/*.gemspec"].map { File.basename(it, ".gemspec") }.sort
  end

  def activated
    (loaded_specs.keys - booted_specs.keys).map { loaded_specs[it].full_name }.sort
  end

  around do |example|
    load_path = $LOAD_PATH.dup
    mirror = "BUNDLE_MIRROR__HTTPS://RUBYGEMS__ORG/"
    ENV[mirror] = "file://#{repo}/"
    application_lockfile = Bundler.default_lockfile
    application_lock = File.read(application_lockfile)
    stub_const(PluginGem, :GEMS_DIR, gems_dir) do
      stub_const(PluginGem, :LOCKFILE, File.join(gems_dir, "Gemfile.lock")) { example.run }
    end
    expect(File.read(application_lockfile)).to eq(application_lock)
  ensure
    ENV.delete(mirror)
    $LOAD_PATH.replace(load_path)
    FileUtils.rm_rf(tmp_dir)
  end

  before do
    build_repo
    app_bundle = Bundler.load
    allow(Bundler).to receive(:load).and_return(
      instance_double(Bundler::Runtime, specs: Bundler::SpecSet.new([*app_bundle.specs, git_gem])),
    )
    FileUtils.mkdir_p(File.dirname(app_lockfile))
    File.write(app_lockfile, "app lock\n")
    allow(Bundler).to receive(:default_lockfile).and_return(Pathname.new(app_lockfile))
    allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
  end

  it "uses the highest shared lock version and pins its transitive dependencies" do
    add_plugin("one", %(gem "alpha", ">= 1"\n), lock: { "alpha" => "1.1.0", "beta" => "1.0.0" })
    add_plugin("two", %(gem "alpha", "~> 1.0"\n), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })

    boot.to output(
      /Installing alpha 1.1.0.*Resolved 2 plugin gems from 2 Gemfiles/m,
    ).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(File.read(File.join(gems_dir, "Gemfile.lock"))).to include(
      "  alpha (1.1.0) #{checksum("alpha", "1.1.0")}\n",
      "  rack (#{rack}) #{checksum("rack", rack)}\n",
    )
  end

  it "fails when two plugins need incompatible versions" do
    add_plugin("one", %(gem "alpha", "~> 1.0.0"\n), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })
    add_plugin("two", %(gem "alpha", ">= 1.1"\n), lock: { "alpha" => "1.1.0", "beta" => "1.0.0" })

    boot.to raise_error(
      %r{alpha \(~> 1.0.0\) in .*/one/Gemfile\nalpha \(>= 1.1\) in .*/two/Gemfile\nalpha \(= 1.1.0\) in .*/two/Gemfile.lock},
    )
    expect(installed).to be_empty
  end

  it "fails when a plugin needs a version of a gem the application has at another one" do
    add_plugin("one", %(gem "rack", "> #{rack}"\n), lock: { "rack" => "99.0.0" })

    boot.to raise_error(
      %r{rack \(> #{rack}\) in .*/one/Gemfile\nrack \(#{rack}\) in the application},
    )
    expect(installed).to be_empty
  end

  it "uses the application's git gem for a direct and a transitive dependency" do
    add_plugin(
      "one",
      %(gem "#{git_gem.name}"\ngem "gamma"\n),
      lock: {
        "gamma" => "1.0.0",
        git_gem.name => git_gem.version.to_s,
      },
    )

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[gamma-1.0.0])
    expect(activated).to eq(%w[gamma-1.0.0])
  end

  it "fails when a plugin needs another version of the application's git gem" do
    name, version = git_gem.name, git_gem.version.to_s
    add_plugin("one", %(gem "#{name}", "> #{version}"\n), lock: { name => "99.0.0" })

    boot.to raise_error(
      %r{#{name} \(> #{version}\) in .*/one/Gemfile\n#{name} \(#{version}\) in the application},
    )
    expect(installed).to be_empty
  end

  it "ignores the development and test groups, also in the Gemfile.lock" do
    add_plugin(
      "one",
      <<~GEMFILE,
      gem "beta"
      gem "not-on-rubygems", group: :development
      gem "neither", groups: %i[test development]
    GEMFILE
      lock: {
        "beta" => "1.0.0",
        "not-on-rubygems" => "1.0.0",
        "neither" => "1.0.0",
      },
    )

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[beta-1.0.0])
  end

  it "resolves a path gem's dependencies and activates it from its directory" do
    dir =
      add_plugin(
        "one",
        %(gem "engine", path: "engine"\ngem "alpha", "~> 1.0"\n),
        lock: {
          "alpha" => "1.1.0",
          "beta" => "1.0.0",
        },
        path: {
          "engine" => ["0.0.1", { "alpha" => ">= 1.1" }],
        },
      )
    FileUtils.mkdir_p(File.join(dir, "engine"))
    File.write(File.join(dir, "engine", "VERSION"), "0.0.1")
    File.write(File.join(dir, "engine", "engine.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = "engine"
        s.version = File.read("VERSION")
        s.summary = "test"
        s.authors = ["test"]
        s.add_dependency "alpha", ">= 1.1"
      end
    GEMSPEC
    engine_file = File.join(dir, "engine", "lib", "plugin_gem_test_engine.rb")
    FileUtils.mkdir_p(File.dirname(engine_file))
    File.write(engine_file, "true\n")

    boot.to output(/Resolved 3 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 engine-0.0.1])
    expect(loaded_specs.fetch("engine").full_gem_path).to eq(File.join(dir, "engine"))
    expect(require "plugin_gem_test_engine").to eq(true)

    $LOADED_FEATURES.delete(engine_file)
    $LOAD_PATH.delete(File.dirname(engine_file))
    boot.not_to output.to_stdout_from_any_process
    expect(require "plugin_gem_test_engine").to eq(true)
  ensure
    $LOADED_FEATURES.delete(engine_file)
  end

  it "uses the application's gem although a plugin has a path gem of that name" do
    dir =
      add_plugin("one", %(gem "rack", path: "rack"\n), lock: {}, path: { "rack" => ["99.0.0", {}] })
    FileUtils.mkdir_p(File.join(dir, "rack"))
    File.write(File.join(dir, "rack", "rack.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = "rack"
        s.version = "99.0.0"
        s.summary = "test"
        s.authors = ["test"]
      end
    GEMSPEC

    boot.to output(/Resolved 0 plugin gems/).to_stdout_from_any_process
    expect(installed).to be_empty
    expect(activated).to be_empty
    expect(File.read(File.join(gems_dir, "Gemfile.lock"))).to include("    rack (#{rack})\n")
  end

  it "resolves again when a gem leaves the application's active bundle" do
    add_plugin("one", %(gem "delta"\n), lock: { "delta" => "1.0.0" })
    boot.to output(/Resolved 0 plugin gems/).to_stdout_from_any_process

    booted_specs.delete(git_gem.name)
    app_specs = Bundler.load.specs.reject { it.name == git_gem.name }
    allow(Bundler).to receive(:load).and_return(
      instance_double(Bundler::Runtime, specs: Bundler::SpecSet.new(app_specs)),
    )

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(activated).to eq(%w[delta-1.0.0])
  end

  it "invalidates the cache when a nested Gemfile enables a locked dependency" do
    dir = add_plugin("one", %(gem "beta"\n), lock: { "beta" => "1.0.0" })
    nested = File.join(dir, "dependencies.rb")
    File.write(nested, %(gem "beta", group: :development\n))
    File.write(
      File.join(dir, "Gemfile"),
      %(source "https://rubygems.org"\neval_gemfile "dependencies.rb"\n),
    )
    boot.to output(/Resolved 0 plugin gems/).to_stdout_from_any_process
    expect(activated).to be_empty

    File.write(nested, %(gem "beta"\n))
    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(activated).to eq(%w[beta-1.0.0])
  end

  it "ignores lock pins from dependencies for another platform" do
    add_plugin(
      "one",
      %(gem "alpha", platforms: :jruby\n),
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.1.0",
      },
    )
    add_plugin("two", %(gem "beta", "1.0.0"\n), lock: { "beta" => "1.0.0" })

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(activated).to eq(%w[beta-1.0.0])
  end

  it "ignores transitive lock pins from other variants when forcing the Ruby gem" do
    dir =
      add_plugin(
        "one",
        %(gem "alpha", force_ruby_platform: true\n),
        lock: {
          "alpha" => "1.1.0",
          "beta" => "1.0.0",
          "shared" => "1.1.0",
        },
      )
    lockfile = File.join(dir, "Gemfile.lock")
    lock = File.read(lockfile)
    ["java", Gem::Platform.local.to_s].each do |platform|
      lock.sub!(
        "    alpha (1.1.0)\n",
        "    alpha (1.1.0-#{platform})\n      shared (>= 1)\n    alpha (1.1.0)\n",
      )
      lock.sub!("PLATFORMS\n", "PLATFORMS\n  #{platform}\n")
      lock.sub!(
        "CHECKSUMS\n",
        "CHECKSUMS\n  alpha (1.1.0-#{platform}) #{checksum("alpha", "1.1.0")}\n",
      )
    end
    File.write(lockfile, lock)
    add_plugin("two", %(gem "shared", "1.0.0"\n), lock: { "shared" => "1.0.0" })

    boot.to output(/Resolved 3 plugin gems/).to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 shared-1.0.0])
  end

  it "rejects an unlocked platform variant before installing any gems" do
    repo_gems << ["beta", "1.0.0", { "shared" => ">= 1" }, Gem::Platform.local.to_s]
    build_repo
    add_plugin("one", %(gem "beta"\n), lock: { "beta" => "1.0.0" })

    boot.to raise_error(/Resolved plugin gem .* is not in the plugins' Gemfile.lock files/)
    expect(installed).to be_empty
  end

  it "rejects a lock with no compatible variant instead of dropping its version pin" do
    dir = add_plugin("one", %(gem "beta"\n), lock: { "beta" => "1.0.0" })
    lockfile = File.join(dir, "Gemfile.lock")
    File.write(lockfile, File.read(lockfile).gsub("beta (1.0.0)", "beta (1.0.0-java)"))

    boot.to raise_error(/Gemfile.lock has no compatible platform for beta/)
    expect(installed).to be_empty
  end

  it "resolves again when a Gemfile or the application's lock changes, reusing what is installed" do
    dir =
      add_plugin("one", %(gem "alpha", "1.0.0"\n), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })
    boot.to output(/Installing beta/).to_stdout_from_any_process

    write_plugin_files(dir, %(gem "alpha", ">= 1.1"\n), { "alpha" => "1.1.0", "beta" => "1.0.0" })
    boot.to output(
      satisfy { it.include?("Installing alpha 1.1.0") && !it.include?("Installing beta") },
    ).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.0.0 alpha-1.1.0 beta-1.0.0])

    File.write(app_lockfile, "app lock, updated\n")
    boot.to output(
      satisfy { it.include?("Resolved 2 plugin gems") && !it.include?("Installing") },
    ).to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
  end

  it "does nothing without a plugin that opts in" do
    add_plugin("one", %(gem "alpha"\n), lock: nil, opt_in: false)

    boot.not_to output.to_stdout_from_any_process
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  it "resolves from the installed gems after a change, and fails for a missing gem when offline" do
    add_plugin("one", %(gem "alpha"\n), lock: { "alpha" => "1.1.0", "beta" => "1.0.0" })
    add_plugin("two", %(gem "shared"\n), lock: { "shared" => "1.1.0" })
    boot.to output(/Resolved 3 plugin gems/).to_stdout_from_any_process

    FileUtils.rm_rf(repo)
    boot.not_to output.to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 shared-1.1.0])

    plugins.pop
    boot.to output(/Resolved 2 plugin gems from 1 Gemfiles/).to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])

    add_plugin("three", %(gem "foo"\n), lock: { "foo" => "2.4.0" })
    boot.to raise_error(/Resolving plugin gems failed: Could not fetch specs/)
  end

  it "refuses a gem source the application doesn't use" do
    add_plugin(
      "one",
      %(gem "alpha"\n),
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.0.0",
      },
      source: "https://gems.example.com",
    )

    boot.to raise_error(
      %r{Plugin one's Gemfile uses the gem source https://gems.example.com/; a plugin's gems must come from the application's gem sources \(https://rubygems.org/\)},
    )
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  it "refuses a git gem" do
    add_plugin(
      "one",
      %(gem "alpha", git: "https://example.com/alpha.git"\n),
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.0.0",
      },
    )

    boot.to raise_error(
      /Plugin one's Gemfile declares alpha from git; a plugin's gems must come from the application's gem sources or a path/,
    )
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  describe "a plugin's Gemfile.lock" do
    it "is required" do
      add_plugin("one", %(gem "alpha"\n), lock: nil)

      boot.to raise_error(
        %r{Plugin one has a Gemfile but no Gemfile.lock; run `bundle lock` in .*/one and commit it},
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "must match its Gemfile" do
      # beta comes with alpha, so the lock doesn't know shared at all.
      dir = add_plugin("one", %(gem "alpha"\n), lock: { "alpha" => "1.1.0", "beta" => "1.0.0" })
      File.write(
        File.join(dir, "Gemfile"),
        %(source "https://rubygems.org"\ngem "alpha"\ngem "shared"\n),
      )

      boot.to raise_error(
        %r{Plugin one's Gemfile.lock does not match its Gemfile; run `bundle lock` in .*/one and commit it\n.*added to the Gemfile:\n\* shared}m,
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "needs checksums" do
      add_plugin(
        "one",
        %(gem "alpha"\n),
        lock: {
          "alpha" => "1.1.0",
          "beta" => "1.0.0",
        },
        checksums: nil,
      )

      boot.to raise_error(
        %r{Plugin one's Gemfile.lock has no checksums; run `bundle lock --add-checksums` in .*/one and commit it},
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "needs a checksum for every gem" do
      dir = add_plugin("one", %(gem "alpha"\n), lock: { "alpha" => "1.1.0", "beta" => "1.0.0" })
      lock = File.join(dir, "Gemfile.lock")
      File.write(lock, File.read(lock).sub(/^  beta .*\n/, ""))

      boot.to raise_error(/does not match its Gemfile.*missing a CHECKSUMS entry for "beta"/m)
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "fails for a gem whose checksum differs" do
      add_plugin(
        "one",
        %(gem "alpha"\n),
        lock: {
          "alpha" => "1.1.0",
          "beta" => "1.0.0",
        },
        checksums: {
          "beta" => "sha256=#{"0" * 64}",
        },
      )

      boot.to raise_error(/Bundler found mismatched checksums.*beta \(1\.0\.0\) sha256=0{64}/m)
      expect(installed).not_to include("beta-1.0.0")
    end

    it "pins its gems, and a newer lock raises the pin" do
      dir = add_plugin("one", %(gem "alpha"\n), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })
      boot.to output(/Resolved 2 plugin gems/).to_stdout_from_any_process
      expect(activated).to eq(%w[alpha-1.0.0 beta-1.0.0])

      write_plugin_files(dir, %(gem "alpha"\n), { "alpha" => "1.1.0", "beta" => "1.0.0" })
      boot.to output(/Installing alpha 1.1.0/).to_stdout_from_any_process
      expect(installed).to eq(%w[alpha-1.0.0 alpha-1.1.0 beta-1.0.0])
      expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
    end

    it "does not pin a gem of the application" do
      add_plugin("one", %(gem "rack"\n), lock: { "rack" => "0.1.0" })

      boot.to output(/Resolved 0 plugin gems/).to_stdout_from_any_process
      expect(installed).to be_empty
    end

    it "fails when its version conflicts with another plugin's requirement" do
      add_plugin("one", %(gem "foo"\n), lock: { "foo" => "2.4.0" })
      add_plugin("two", %(gem "foo", "~> 2.3.0"\n), lock: { "foo" => "2.3.1" })

      boot.to raise_error(
        %r{foo \(>= 0\) in .*/one/Gemfile\nfoo \(~> 2.3.0\) in .*/two/Gemfile\nfoo \(= 2.4.0\) in .*/one/Gemfile.lock},
      )
      expect(installed).to be_empty
    end
  end
end
