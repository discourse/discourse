# frozen_string_literal: true

require "rubygems/package"

RSpec.describe PluginGem do
  let(:tmp_dir) { Dir.mktmpdir("plugin-gem-spec") }
  let(:repo) { File.join(tmp_dir, "repo") }
  let(:gems_dir) { File.join(tmp_dir, "plugin-gems") }
  let(:app_lockfile) { File.join(tmp_dir, "app", "Gemfile.lock") }
  let(:app_versions) { Bundler.load.specs.to_h { [it.name, it.version.to_s] } }
  let(:rack) { app_versions.fetch("rack") }
  let!(:booted_specs) { Gem.loaded_specs.dup }
  let(:loaded_specs) { booted_specs.dup }
  let(:plugins) { [] }

  def build_repo
    gems = [
      ["alpha", "1.0.0", { "beta" => "~> 1.0", "rack" => ">= 1" }],
      ["alpha", "1.1.0", { "beta" => "~> 1.0", "rack" => ">= 1" }],
      %w[beta 1.0.0],
      ["gamma", "1.0.0", { "raindrops" => ">= 0" }],
      %w[shared 1.0.0],
      %w[shared 1.1.0],
      %w[foo 2.3.1],
      %w[foo 2.4.0],
      ["bar", "1.0.0", { "foo" => ">= 2.4" }],
      # Newer than anything the application has, so only a pin keeps them out.
      %w[rack 99.0.0],
    ]
    specs =
      gems.map do |name, version, dependencies = {}|
        Gem::Specification.new do |spec|
          spec.name = name
          spec.version = version
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

  def add_plugin(name, gemfile, opt_in: true)
    dir = File.join(tmp_dir, "plugins", name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "plugin.rb"), "# name: #{name}\n# gemfile: #{opt_in}\n")
    File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n#{gemfile}")
    plugins << Plugin::Instance.parse_from_source(File.join(dir, "plugin.rb"))
    dir
  end

  def write_plugin_lock(dir, locked)
    File.write(File.join(dir, "Gemfile.lock"), <<~LOCK)
      GEM
        remote: https://rubygems.org/
        specs:
      #{locked.map { |name, version| "    #{name} (#{version})" }.join("\n")}

      PLATFORMS
        ruby

      DEPENDENCIES
      #{locked.keys.map { |name| "  #{name}" }.join("\n")}
    LOCK
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
    FileUtils.mkdir_p(File.dirname(app_lockfile))
    File.write(app_lockfile, "app lock\n")
    allow(Bundler).to receive(:default_lockfile).and_return(Pathname.new(app_lockfile))
    allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
  end

  it "resolves a gem two plugins share once" do
    add_plugin("one", %(gem "alpha", ">= 1"\n))
    add_plugin("two", %(gem "alpha", "~> 1.0"\n))

    boot.to output(
      /Installing alpha 1.1.0.*Resolved 2 plugin gems from 2 Gemfiles/m,
    ).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
  end

  it "fails when two plugins need incompatible versions" do
    add_plugin("one", %(gem "alpha", "~> 1.0.0"\n))
    add_plugin("two", %(gem "alpha", ">= 1.1"\n))

    boot.to raise_error(
      %r{alpha \(~> 1.0.0\) in .*/one/Gemfile\nalpha \(>= 1.1\) in .*/two/Gemfile},
    )
    expect(installed).to be_empty
  end

  it "fails when a plugin needs a version of a gem the application has at another one" do
    add_plugin("one", %(gem "rack", "> #{rack}"\n))

    boot.to raise_error(
      %r{rack \(> #{rack}\) in .*/one/Gemfile\nrack \(#{rack}\) in the application},
    )
    expect(installed).to be_empty
  end

  it "uses the application's git gem for a direct and a transitive dependency" do
    add_plugin("one", %(gem "raindrops"\ngem "gamma"\n))

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[gamma-1.0.0])
    expect(activated).to eq(%w[gamma-1.0.0])
  end

  it "ignores the development and test groups" do
    add_plugin("one", <<~GEMFILE)
      gem "beta"
      gem "not-on-rubygems", group: :development
      gem "neither", groups: %i[test development]
    GEMFILE

    boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[beta-1.0.0])
  end

  it "resolves a path gem's dependencies and activates it from its directory" do
    dir = add_plugin("one", %(gem "engine", path: "engine"\ngem "alpha", "~> 1.0"\n))
    FileUtils.mkdir_p(File.join(dir, "engine"))
    File.write(File.join(dir, "engine", "engine.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = "engine"
        s.version = "0.0.1"
        s.summary = "test"
        s.authors = ["test"]
        s.add_dependency "alpha", ">= 1.1"
      end
    GEMSPEC

    boot.to output(/Resolved 3 plugin gems/).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.1.0 beta-1.0.0])
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0 engine-0.0.1])
  end

  it "only activates on the next boot" do
    add_plugin("one", %(gem "alpha"\n))
    boot.to output(/Resolved 2 plugin gems/).to_stdout_from_any_process

    FileUtils.rm_rf(repo)
    boot.not_to output.to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
  end

  it "resolves again when a Gemfile or the application's lock changes, reusing what is installed" do
    dir = add_plugin("one", %(gem "alpha", "1.0.0"\n))
    boot.to output(/Installing beta/).to_stdout_from_any_process

    File.write(File.join(dir, "Gemfile"), %(source "https://rubygems.org"\ngem "alpha", ">= 1.1"\n))
    boot.to output(
      satisfy { it.include?("Installing alpha 1.1.0") && !it.include?("Installing beta") },
    ).to_stdout_from_any_process
    expect(installed).to eq(%w[alpha-1.0.0 alpha-1.1.0 beta-1.0.0])

    allow(PluginGem).to receive(:in_child_process).and_call_original
    File.write(app_lockfile, "app lock, updated\n")
    boot.not_to output(/Installing/).to_stdout_from_any_process
    expect(PluginGem).to have_received(:in_child_process)
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
  end

  it "does nothing without a plugin that opts in" do
    add_plugin("one", %(gem "alpha"\n), opt_in: false)

    boot.not_to output.to_stdout_from_any_process
    expect(Dir.exist?(gems_dir)).to eq(false)
  end

  it "resolves from the installed gems after a change, and fails for a missing gem when offline" do
    add_plugin("one", %(gem "alpha"\n))
    add_plugin("two", %(gem "shared"\n))
    boot.to output(/Resolved 3 plugin gems/).to_stdout_from_any_process

    FileUtils.rm_rf(repo)
    plugins.pop
    boot.to output(/Resolved 2 plugin gems from 1 Gemfiles/).to_stdout_from_any_process
    expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])

    add_plugin("three", %(gem "foo"\n))
    boot.to raise_error(/Resolving plugin gems failed: Could not fetch specs/)
  end

  describe "a plugin's Gemfile.lock" do
    it "bounds its direct dependencies, and a newer lock raises the bound" do
      dir = add_plugin("one", %(gem "alpha"\n))
      write_plugin_lock(dir, "alpha" => "1.0.0", "beta" => "1.0.0")
      boot.to output(/Resolved 2 plugin gems/).to_stdout_from_any_process
      expect(activated).to eq(%w[alpha-1.0.0 beta-1.0.0])

      write_plugin_lock(dir, "alpha" => "1.1.0", "beta" => "1.0.0")
      boot.to output(/Installing alpha 1.1.0/).to_stdout_from_any_process
      expect(installed).to eq(%w[alpha-1.0.0 alpha-1.1.0 beta-1.0.0])
      expect(activated).to eq(%w[alpha-1.1.0 beta-1.0.0])
    end

    it "bounds a shared gem by the highest version any plugin locks" do
      write_plugin_lock(add_plugin("one", %(gem "shared"\n)), "shared" => "1.1.0")
      write_plugin_lock(add_plugin("two", %(gem "shared"\n)), "shared" => "1.0.0")

      boot.to output(/Resolved 1 plugin gems/).to_stdout_from_any_process
      expect(installed).to eq(%w[shared-1.1.0])
    end

    it "does not bound a gem of the application" do
      write_plugin_lock(add_plugin("one", %(gem "rack"\n)), "rack" => "0.1.0")

      boot.to output(/Resolved 0 plugin gems/).to_stdout_from_any_process
      expect(installed).to be_empty
    end

    it "is given up when the plugins can't be resolved with it" do
      write_plugin_lock(add_plugin("one", %(gem "foo"\n)), "foo" => "2.3.1")
      add_plugin("two", %(gem "bar"\n))

      boot.to output(
        /Gemfile.lock versions could not be kept.*Installing foo 2.4.0.*Resolved 2 plugin gems/m,
      ).to_stdout_from_any_process
      expect(installed).to eq(%w[bar-1.0.0 foo-2.4.0])
    end
  end
end
