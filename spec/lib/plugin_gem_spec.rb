# frozen_string_literal: true

require "rubygems/package"
require "bundler/lockfile_generator"

RSpec.describe PluginGem do
  let(:tmp_dir) { Dir.mktmpdir("plugin-gem-spec") }
  let(:repo) { File.join(tmp_dir, "repo") }
  let(:gems_dir) { File.join(tmp_dir, "plugin-gems") }
  let(:app_versions) { Bundler.load.specs.to_h { [it.name, it.version.to_s] } }
  let(:rack) { app_versions.fetch("rack") }
  let(:app_checksums) do
    File.read(Rails.root.join("Gemfile.lock")).scan(/^  (\S+) \([^)]+\) (sha256=\h+)$/).to_h
  end
  let!(:booted_specs) { Gem.loaded_specs.dup.merge(git_gem.name => git_gem) }
  let(:loaded_specs) { booted_specs.dup }
  let(:plugins) { [] }
  let(:alpha_lock) { { "alpha" => "1.1.0", "beta" => "1.0.0" } }
  # Plays the role of a gem the application loads from git. Once checked out,
  # a git gem is a path source for bundler: a directory with a gemspec. Only
  # that directory matters here.
  let(:git_gem) do
    dir = File.join(tmp_dir, "app", "delta")
    write_gemspec(dir, "delta", "1.0.0")
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
      # Newer than anything the application has, so only a pin keeps them out.
      %w[rack 99.0.0],
    ]
  end

  def gem_spec(name, version, dependencies = {}, platform = "ruby")
    Gem::Specification.new do |spec|
      spec.name = name
      spec.version = version
      spec.platform = platform
      spec.summary = name
      spec.authors = ["test"]
      dependencies.each { |dependency, requirement| spec.add_dependency(dependency, requirement) }
    end
  end

  def write_gemspec(dir, name, version)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{name}.gemspec"), gem_spec(name, version).to_ruby)
  end

  def build_repo
    specs = repo_gems.map { gem_spec(*it) }
    FileUtils.mkdir_p(["#{repo}/gems", "#{repo}/quick/Marshal.4.8"])
    specs.each do |spec|
      yield spec if block_given?
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

  # `lock` is name => version. The Gemfile.lock is written as `bundle lock`
  # would write it, with dependencies and checksums taken from the repo. nil
  # writes no Gemfile.lock. `path` adds path gems: name => [version,
  # dependencies]. `checksums` replaces checksums by gem name; nil writes no
  # CHECKSUMS section.
  def add_plugin(name, gemfile, lock:, opt_in: true, **options)
    dir = File.join(tmp_dir, "plugins", name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "plugin.rb"), "# name: #{name}\n# gemfile: #{opt_in}\n")
    write_plugin_files(dir, gemfile.chomp, lock, **options)
    plugins << Plugin::Instance.parse_from_source(File.join(dir, "plugin.rb"))
    dir
  end

  def write_plugin_files(
    dir,
    gemfile,
    lock,
    path: {},
    checksums: {},
    source: "https://rubygems.org",
    scoped: false
  )
    gemfile =
      if scoped
        <<~GEMFILE
          source "#{source}" do
          #{gemfile}
          end
        GEMFILE
      else
        <<~GEMFILE
          source "#{source}"
          #{gemfile}
        GEMFILE
      end
    File.write(File.join(dir, "Gemfile"), gemfile)
    return if lock.nil?

    lockfile = File.join(dir, "Gemfile.lock")
    definition = Bundler::Definition.build(File.join(dir, "Gemfile"), lockfile, nil)
    definition.sources.git_sources.clear
    gems =
      lock.map do |name, version|
        [name, version, repo_gems.find { it[0] == name && it[1] == version }&.dig(2)]
      end
    # `bundle lock` would add the application's gems the plugin's gems need.
    app_gems = gems.flat_map { it[2]&.keys || [] }.uniq - lock.keys
    gems += app_gems.map { [it, app_versions.fetch(it), nil] }
    rubygems_source =
      definition.sources.non_global_rubygems_sources.first ||
        definition.sources.global_rubygems_source
    specs = gems.map { locked_spec(*it, rubygems_source) }
    specs +=
      path.map do |name, (version, dependencies)|
        source = definition.sources.path_sources.find { it.path.to_s == name }
        locked_spec(name, version, dependencies, source)
      end
    add_checksums(specs, checksums, lockfile) if checksums
    lock_definition =
      instance_double(
        Bundler::Definition,
        sources: definition.sources,
        resolve: Bundler::SpecSet.new(specs),
        platforms: [Gem::Platform::RUBY],
        dependencies: definition.dependencies,
        locked_checksums: !checksums.nil?,
        locked_ruby_version: nil,
        bundler_version_to_lock: Bundler.gem_version,
      )
    File.write(lockfile, Bundler::LockfileGenerator.generate(lock_definition))
  end

  def locked_spec(name, version, dependencies, source)
    spec =
      Bundler::LazySpecification.new(name, Gem::Version.new(version), Gem::Platform::RUBY, source)
    spec.dependencies = dependencies&.map { Gem::Dependency.new(*it) } || []
    spec
  end

  def add_checksums(specs, checksums, lockfile)
    specs.each do |spec|
      value = checksum(spec.name, spec.version) if spec.source.is_a?(Bundler::Source::Rubygems)
      value = checksums.fetch(spec.name, value)
      parsed = Bundler::Checksum.from_lock(value, lockfile) if value
      spec.source.checksum_store.register(spec, parsed)
    end
  end

  def checksum(name, version)
    gem = "#{repo}/gems/#{name}-#{version}.gem"
    return "sha256=#{Digest::SHA256.file(gem).hexdigest}" if File.exist?(gem)

    # The application's lock has no checksums for its path and git gems, so
    # those get a made-up one.
    app_checksums.fetch(name) { "sha256=#{Digest::SHA256.hexdigest(name)}" }
  end

  # A fresh process: only the application's gems are activated.
  def boot
    loaded_specs.replace(booted_specs)
    PluginGem.activate_gemfiles(plugins)
  end

  # Bundler's temporary settings can't hold an empty group list: an empty
  # value removes the key, and the host's bundle config shows through. The
  # child resets the settings, so every instance is stubbed.
  def boot_with_groups(with: [], without: [], only: [])
    groups = { with:, without:, only: }
    allow_any_instance_of(Bundler::Settings).to receive(:[]).and_wrap_original do |original, key|
      groups.fetch(key.to_sym) { original.call(key) }
    end
    boot
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
    allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
  end

  it "uses the highest shared lock version and pins its transitive dependencies" do
    add_plugin(
      "one",
      <<~GEMFILE,
        gem "alpha", ">= 1"
        gem "rack"
      GEMFILE
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.0.0",
        "rack" => "99.0.0",
      },
    )
    add_plugin("two", %(gem "alpha", "~> 1.0"), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })

    boot
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(File.read(File.join(gems_dir, "Gemfile.lock"))).to include(
      "  alpha (1.1.0) #{checksum("alpha", "1.1.0")}\n",
      "  rack (#{rack}) #{checksum("rack", rack)}\n",
    )
  end

  it "fails when the highest shared lock version does not satisfy another plugin" do
    add_plugin("one", %(gem "alpha"), lock: alpha_lock)
    add_plugin("two", %(gem "alpha", "~> 1.0.0"), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })

    expect { boot }.to raise_error(
      %r{Resolving plugin gems failed for .*/one/Gemfile, .*/two/Gemfile:.*alpha.*1.1.0}m,
    )
    expect(installed).to be_empty
  end

  it "fails when a plugin needs a version of a gem the application has at another one" do
    add_plugin("one", %(gem "rack", "> #{rack}"), lock: { "rack" => "99.0.0" })

    expect { boot }.to raise_error(
      %r{Resolving plugin gems failed for .*/one/Gemfile:.*rack.*#{rack}}m,
    )
    expect(installed).to be_empty
  end

  it "uses the application's git gem for a direct and a transitive dependency" do
    add_plugin(
      "one",
      <<~GEMFILE,
        gem "#{git_gem.name}"
        gem "gamma"
      GEMFILE
      lock: {
        "gamma" => "1.0.0",
        git_gem.name => git_gem.version.to_s,
      },
    )

    boot
    expect(installed).to eq(%w[gamma-1.0.0])
    expect(activated).to eq(%w[gamma-1.0.0])
  end

  it "fails when a plugin needs another version of the application's git gem" do
    name, version = git_gem.name, git_gem.version.to_s
    add_plugin("one", %(gem "#{name}", "> #{version}"), lock: { name => "99.0.0" })

    expect { boot }.to raise_error(
      %r{Resolving plugin gems failed for .*/one/Gemfile:.*#{name}.*#{version}}m,
    )
    expect(installed).to be_empty
  end

  it "loads dependencies from the groups enabled for the application" do
    add_plugin(
      "one",
      <<~GEMFILE,
      gem "beta"
      gem "alpha", group: :development
      gem "shared", group: :test
      gem "gamma", group: :migrations
    GEMFILE
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.0.0",
        "gamma" => "1.0.0",
        git_gem.name => git_gem.version.to_s,
        "shared" => "1.0.0",
      },
    )

    boot_with_groups(without: %i[development test])
    expect(activated).to eq(%w[beta-1.0.0])

    boot_with_groups(without: %i[development])
    expect(activated).to eq(%w[beta-1.0.0 shared-1.0.0])

    boot_with_groups
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 shared-1.0.0])

    boot_with_groups(only: %i[development])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])

    boot_with_groups(with: %i[migrations], without: %i[development test])
    expect(activated).to eq(%w[beta-1.0.0 gamma-1.0.0])
  end

  it "ignores dependencies for other platforms when selecting lock pins" do
    add_plugin(
      "one",
      %(gem "alpha", platforms: :jruby),
      lock: {
        "alpha" => "1.1.0",
        "beta" => "1.1.0",
      },
    )

    boot
    expect(installed).to be_empty
  end

  it "resolves a path gem's dependencies and activates it from its directory" do
    dir =
      add_plugin(
        "one",
        <<~GEMFILE,
          gem "engine", path: "engine"
          gem "alpha", "~> 1.0"
        GEMFILE
        lock: alpha_lock,
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
        s.require_paths = ["src"]
        s.add_dependency "alpha", ">= 1.1"
      end
    GEMSPEC
    engine_file = File.join(dir, "engine", "src", "plugin_gem_test_engine.rb")
    FileUtils.mkdir_p(File.dirname(engine_file))
    File.write(engine_file, "true\n")

    boot
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 engine-0.0.1])
    expect(require "plugin_gem_test_engine").to eq(true)

    File.write(File.join(dir, "engine", "VERSION"), "2.0.0")
    expect { boot }.to raise_error(/Gemfile.lock does not match its Gemfile/)
    expect(activated).to be_empty
  ensure
    $LOADED_FEATURES.delete(engine_file)
  end

  it "rejects a path gem without a gemspec before installing any gems" do
    dir =
      add_plugin(
        "one",
        %(gem "engine", "0.0.1", path: "engine"),
        lock: {
        },
        path: {
          "engine" => ["0.0.1", {}],
        },
      )
    FileUtils.mkdir_p(File.join(dir, "engine"))

    expect { boot }.to raise_error("Plugin path gem engine needs a .gemspec file in #{dir}/engine")
    expect(installed).to be_empty
    expect(activated).to be_empty
  end

  it "pins core gems and their dependencies when overriding a plugin's path source" do
    dir =
      add_plugin(
        "one",
        %(gem "rack-test", path: "rack-test"),
        lock: {
        },
        path: {
          "rack-test" => ["99.0.0", {}],
        },
      )
    write_gemspec(File.join(dir, "rack-test"), "rack-test", "99.0.0")

    boot
    expect(installed).to be_empty
    expect(activated).to be_empty
    expect(File.read(File.join(gems_dir, "Gemfile.lock"))).to include(
      "    rack-test (#{app_versions.fetch("rack-test")})\n",
      "    rack (#{rack})\n",
    )
  end

  it "honors core's lock even when the gem is outside core's active groups" do
    core_dir = add_plugin("core", %(gem "beta"), lock: { "beta" => "1.0.0" })
    plugins.clear
    core_lock = Bundler::LockfileParser.new(File.read(File.join(core_dir, "Gemfile.lock")))
    allow(Bundler.definition).to receive(:locked_gems).and_return(core_lock)
    dir = add_plugin("one", %(gem "beta"), lock: { "beta" => "1.1.0" })

    boot
    expect(activated).to eq(%w[beta-1.0.0])

    write_plugin_files(dir, %(gem "beta", ">= 1.1"), { "beta" => "1.1.0" })
    expect { boot }.to raise_error(/Resolving plugin gems failed.*beta/m)
    expect(installed).to eq(%w[beta-1.0.0])
    expect(activated).to be_empty
  end

  it "reevaluates nested Gemfiles and conditional dependencies on each boot" do
    previous = ENV["PLUGIN_GEM_TEST_BETA"]
    dir = add_plugin("one", %(gem "beta"), lock: { "beta" => "1.0.0" })
    nested = File.join(dir, "dependencies.rb")
    File.write(nested, %(gem "beta", group: :development\n))
    File.write(
      File.join(dir, "Gemfile"),
      %(source "https://rubygems.org"\neval_gemfile "dependencies.rb"\n),
    )
    boot_with_groups(without: %i[development])
    expect(activated).to be_empty

    File.write(nested, <<~GEMFILE)
      install_if -> { ENV["PLUGIN_GEM_TEST_BETA"] == "1" } do
        gem "beta"
      end
    GEMFILE
    ENV["PLUGIN_GEM_TEST_BETA"] = "1"
    boot
    expect(activated).to eq(%w[beta-1.0.0])

    ENV["PLUGIN_GEM_TEST_BETA"] = "0"
    boot
    expect(activated).to be_empty
  ensure
    ENV["PLUGIN_GEM_TEST_BETA"] = previous
  end

  it "ignores transitive lock pins from other variants when forcing the Ruby gem" do
    dir =
      add_plugin(
        "one",
        %(gem "alpha", force_ruby_platform: true),
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
    add_plugin("two", %(gem "shared", "1.0.0"), lock: { "shared" => "1.0.0" })

    boot
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 shared-1.0.0])
  end

  it "rejects unlocked variants and dependencies deep in the graph before installing any gems" do
    repo_gems << ["chain", "1.0.0", { "alpha" => ">= 1" }]
    repo_gems << ["beta", "1.0.0", { "shared" => ">= 1" }, Gem::Platform.local.to_s]
    build_repo
    add_plugin(
      "one",
      %(gem "chain"),
      lock: {
        "chain" => "1.0.0",
        "alpha" => "1.1.0",
        "beta" => "1.0.0",
      },
    )

    expect { boot }.to raise_error(
      /Resolved plugin gem .* is not in the committed Gemfile.lock files/,
    )
    expect(installed).to be_empty
  end

  it "rejects a replacement platform variant of an active core gem" do
    repo_gems << ["rack", rack, {}, Gem::Platform.local.to_s]
    build_repo
    add_plugin("one", %(gem "alpha"), lock: alpha_lock)

    expect { boot }.to raise_error(/Resolved plugin bundle would replace core gem rack-/)
    expect(installed).to be_empty
    expect(activated).to be_empty
  end

  it "rejects a lock with no compatible variant instead of dropping its version pin" do
    dir = add_plugin("one", %(gem "beta"), lock: { "beta" => "1.0.0" })
    lockfile = File.join(dir, "Gemfile.lock")
    File.write(lockfile, File.read(lockfile).gsub("beta (1.0.0)", "beta (1.0.0-java)"))

    expect { boot }.to raise_error(/Gemfile.lock has no compatible platform for beta/)
    expect(installed).to be_empty
  end

  it "builds extensions without inheriting the application's bundle" do
    repo_gems << %w[native 1.0.0]
    Dir.chdir(tmp_dir) do
      File.write("extconf.rb", 'File.write("Makefile", "all install clean:\n\t@true\n")')
      build_repo { |spec| spec.files = spec.extensions = ["extconf.rb"] if spec.name == "native" }
    end
    add_plugin("one", %(gem "native"), lock: { "native" => "1.0.0" })

    boot
    expect(activated).to eq(%w[native-1.0.0])
    expect(loaded_specs.fetch("native").missing_extensions?).to eq(false)
  end

  it "does nothing without a plugin that opts in" do
    add_plugin("one", %(gem "alpha"), lock: nil, opt_in: false)

    expect { boot }.not_to output.to_stdout_from_any_process
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  it "resolves from the installed gems after a change, and fails for a missing gem when offline" do
    add_plugin("one", %(gem "alpha"), lock: alpha_lock)
    add_plugin("two", %(gem "shared"), lock: { "shared" => "1.1.0" })
    boot

    FileUtils.rm_rf(repo)
    expect { boot }.not_to output(/Fetching|Installing/).to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 shared-1.1.0])

    gem_dir = loaded_specs.fetch("alpha").full_gem_path
    FileUtils.rm_rf(gem_dir)
    plugins.pop
    boot
    expect(Dir.exist?(gem_dir)).to eq(true)
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])

    add_plugin("three", %(gem "beta", ">= 1.1"), lock: { "beta" => "1.1.0" })
    expect { boot }.to raise_error(/Resolving plugin gems failed.*Could not fetch specs/)
  end

  it "refuses a gem source the application doesn't use" do
    add_plugin("one", %(gem "alpha"), lock: alpha_lock, source: "https://gems.example.com")

    expect { boot }.to raise_error(
      %r{Plugin one's Gemfile uses the gem source https://gems.example.com/; a plugin's gems must come from the application's gem sources \(https://rubygems.org/\)},
    )
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  it "refuses a git gem" do
    add_plugin("one", %(gem "alpha", git: "https://example.com/alpha.git"), lock: alpha_lock)

    expect { boot }.to raise_error(
      /Plugin one's Gemfile declares alpha from git; a plugin's gems must come from the application's gem sources or a path/,
    )
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  describe "a plugin's Gemfile.lock" do
    it "is required" do
      add_plugin("one", %(gem "alpha"), lock: nil)

      expect { boot }.to raise_error(
        %r{Plugin one has a Gemfile but no Gemfile.lock; run `bundle lock` in .*/one and commit it},
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "must match its Gemfile" do
      # beta is a dependency of alpha and so in the lock; shared isn't in the
      # lock at all.
      dir = add_plugin("one", %(gem "alpha"), lock: alpha_lock)
      File.write(
        File.join(dir, "Gemfile"),
        %(source "https://rubygems.org"\ngem "alpha"\ngem "shared"\n),
      )

      expect { boot }.to raise_error(
        %r{Plugin one's Gemfile.lock does not match its Gemfile; run `bundle lock` in .*/one and commit it\n.*added to the Gemfile:\n\* shared}m,
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "needs checksums" do
      add_plugin("one", %(gem "alpha"), lock: alpha_lock, checksums: nil)

      expect { boot }.to raise_error(
        %r{Plugin one's Gemfile.lock has no checksums; run `bundle lock --add-checksums` in .*/one and commit it},
      )
      expect(Dir.exist?(gems_dir)).to eq(false)
    end

    it "needs a SHA256 checksum for every downloaded gem" do
      dir = add_plugin("one", %(gem "alpha"), lock: alpha_lock)
      lock = File.join(dir, "Gemfile.lock")
      contents = File.read(lock)
      File.write(lock, contents.sub(/^  beta .*\n/, ""))

      expect { boot }.to raise_error(
        /does not match its Gemfile.*missing a CHECKSUMS entry for "beta"/m,
      )
      expect(Dir.exist?(gems_dir)).to eq(false)

      File.write(lock, contents.sub(checksum("beta", "1.0.0"), "sha512=#{"0" * 128}"))
      expect { boot }.to raise_error(/Locked gem beta-1.0.0 has no SHA256 checksum/)
      expect(installed).to be_empty
    end

    it "fails for a gem whose checksum differs" do
      add_plugin(
        "one",
        %(gem "alpha"),
        lock: alpha_lock,
        checksums: {
          "beta" => "sha256=#{"0" * 64}",
        },
      )

      Bundler
        .settings
        .temporary(disable_checksum_validation: true) do
          expect { boot }.to raise_error(
            /Bundler found mismatched checksums.*beta \(1\.0\.0\) sha256=0{64}/m,
          )
        end
      expect(installed).not_to include("beta-1.0.0")
    end

    it "verifies the checksums of every plugin when the first one scopes its source" do
      add_plugin("one", %(  gem "alpha"), lock: alpha_lock, scoped: true)
      add_plugin(
        "two",
        %(gem "shared"),
        lock: {
          "shared" => "1.1.0",
        },
        checksums: {
          "shared" => "sha256=#{"0" * 64}",
        },
      )

      expect { boot }.to raise_error(
        /Bundler found mismatched checksums.*shared \(1\.1\.0\) sha256=0{64}/m,
      )
      expect(installed).not_to include("shared-1.1.0")
    end

    it "updates pinned gems when the lock changes and reuses unchanged dependencies" do
      dir = add_plugin("one", %(gem "alpha"), lock: { "alpha" => "1.0.0", "beta" => "1.0.0" })
      boot
      expect(activated).to eq(%w[alpha-1.0.0 beta-1.0.0])

      write_plugin_files(dir, %(gem "alpha"), alpha_lock)
      expect { boot }.to output(
        satisfy { it.include?("Installing alpha 1.1.0") && !it.include?("Installing beta") },
      ).to_stdout_from_any_process
      expect(installed).to eq(%w[alpha-1.0.0 alpha-1.1.0 beta-1.0.0])
      expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
    end
  end
end
