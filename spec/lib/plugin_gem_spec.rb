# frozen_string_literal: true

RSpec.describe PluginGem do
  let(:plugin_dir) { Dir.mktmpdir("plugin-gem-spec") }
  let(:plugin_path) { File.join(plugin_dir, "plugin.rb") }
  let(:gems_path) { File.join(plugin_dir, "gems", RUBY_VERSION) }
  let(:lock_path) { File.join(plugin_dir, "Gemfile.lock") }
  let(:plugin_name) { File.basename(plugin_dir) }

  after { FileUtils.rm_rf(plugin_dir) }

  # What `bundle lock` writes for a plugin Gemfile: a gem with one dependency
  # of its own and one the application already has.
  def write_gemfile_lock(markbridge_version: "0.4.3", rack_requirement: ">= 3")
    File.write(lock_path, <<~LOCK)
      GEM
        remote: https://rubygems.org/
        specs:
          markbridge (#{markbridge_version})
            rack (#{rack_requirement})
            zeitwerk-lite (~> 1.0)
          rack (3.2.0)
          zeitwerk-lite (1.0.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        markbridge
    LOCK
  end

  describe ".resolve" do
    let(:bundle_specs) { { "pg" => "1.6.3", "rack" => "3.1.0" } }
    let(:unpinnable) { { "raindrops" => "git" } }
    let(:activated) { {} }
    let(:requirements) { { "markbridge" => ">= 0.4.0", "rack" => ">= 3" } }
    let(:resolved) do
      [
        { "name" => "markbridge", "version" => "0.4.3", "dependencies" => ["zeitwerk-lite"] },
        { "name" => "zeitwerk-lite", "version" => "1.0.0", "dependencies" => [] },
      ]
    end

    def resolve
      described_class.resolve(plugin_path, requirements)
    end

    before do
      File.write(plugin_path, "# name: sample-plugin\n")
      allow(described_class).to receive(:bundle_specs_by_name) { bundle_specs }
      allow(described_class).to receive(:unpinnable_bundle_gems) { unpinnable }
      allow(described_class).to receive(:activated_plugin_gems) { activated }
      allow(described_class).to receive(:resolve_with_bundler).and_return(resolved)
      allow(described_class).to receive(:install_resolved)
      allow(described_class).to receive(:activate_resolved)
    end

    it "refuses a requirement the application's locked version cannot satisfy" do
      requirements["pg"] = ">= 2"
      write_gemfile_lock

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin #{plugin_name} needs pg >= 2, but the application locks pg 1.6.3",
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
      expect(described_class).not_to have_received(:install_resolved)
    end

    it "refuses a requirement a gem activated by an earlier plugin cannot satisfy" do
      activated["samovar"] = "2.5.1"
      requirements["samovar"] = "< 2.5"

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin #{plugin_name} needs samovar < 2.5, but samovar 2.5.1 is already activated",
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
    end

    it "pins the gems an earlier plugin activated like the application's" do
      activated["samovar"] = "2.5.1"
      requirements["samovar"] = ">= 2.5"

      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler).with(
        plugin_name,
        bundle_specs.merge("samovar" => "2.5.1"),
        unpinnable,
        requirements,
      )
    end

    it "takes two bounds as an array" do
      requirements["pg"] = [">= 2", "< 3"]

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin #{plugin_name} needs pg >= 2, < 3, but the application locks pg 1.6.3",
      )
    end

    it "takes symbol keys" do
      requirements[:pg] = ">= 2"

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin #{plugin_name} needs pg >= 2, but the application locks pg 1.6.3",
      )
    end

    it "takes the Gemfile.lock entry for the local platform" do
      requirements.replace("nokogiri" => ">= 1.18")
      # The generic entry needs a build helper the precompiled one does not.
      File.write(lock_path, <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            mini_portile2 (2.8.9)
            nokogiri (1.18.0)
              mini_portile2 (~> 2.8)
              racc (~> 1.4)
            nokogiri (1.18.0-#{Gem::Platform.local})
              racc (~> 1.4)
            racc (1.8.1)

        PLATFORMS
          ruby
          #{Gem::Platform.local}

        DEPENDENCIES
          nokogiri
      LOCK

      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(described_class).not_to have_received(:resolve_with_bundler)
      expect(described_class).to have_received(:install_resolved).with(
        gems_path,
        [
          { "name" => "nokogiri", "version" => "1.18.0", "dependencies" => ["racc"] },
          { "name" => "racc", "version" => "1.8.1", "dependencies" => [] },
        ],
      )
    end

    it "refuses a requirement for a gem the application loads from git or a path" do
      requirements["raindrops"] = ">= 0.20"

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin #{plugin_name} needs raindrops >= 0.20, but the application loads raindrops from git; " \
          "drop the requirement, the gem is already activated",
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
    end

    it "uses the plugin's Gemfile.lock and drops the gems the application has" do
      write_gemfile_lock

      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(described_class).not_to have_received(:resolve_with_bundler)
      # rack is the application's, so it is neither installed nor a dependency
      # to activate; its version in the plugin's lock does not matter.
      expect(described_class).to have_received(:install_resolved).with(gems_path, resolved)
      expect(described_class).to have_received(:activate_resolved).with(gems_path, resolved)
    end

    it "says which locked versions the application replaces at runtime" do
      write_gemfile_lock

      expect { resolve }.to output(
        /#{plugin_name}: rack 3.2.0 in Gemfile.lock is 3.1.0 in the application/,
      ).to_stdout
      expect(described_class).not_to have_received(:resolve_with_bundler)
    end

    it "ignores Gemfile.lock when a locked gem needs a version the application does not have" do
      write_gemfile_lock(rack_requirement: ">= 3.2")

      expect { resolve }.to output(
        /#{plugin_name}: Gemfile.lock ignored: markbridge 0.4.3 needs rack >= 3.2, but the application locks rack 3.1.0/,
      ).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler)
      expect(described_class).to have_received(:install_resolved).with(gems_path, resolved)
    end

    it "ignores Gemfile.lock when a required gem is missing from it" do
      requirements["samovar"] = ">= 2.5"
      write_gemfile_lock

      expect { resolve }.to output(
        /#{plugin_name}: Gemfile.lock ignored: samovar is not in Gemfile.lock/,
      ).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler)
    end

    it "ignores Gemfile.lock when a locked version does not satisfy" do
      write_gemfile_lock(markbridge_version: "0.3.0")

      expect { resolve }.to output(
        /#{plugin_name}: Gemfile.lock ignored: markbridge 0.3.0 does not satisfy >= 0.4.0/,
      ).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler).with(
        plugin_name,
        bundle_specs,
        unpinnable,
        requirements,
      )
      expect(described_class).to have_received(:activate_resolved).with(gems_path, resolved)
    end

    it "caches the resolution per bundle and reuses it" do
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      manifests = Dir["#{gems_path}/resolved-*.json"]
      expect(manifests.size).to eq(1)
      expect(JSON.parse(File.read(manifests.first))["gems"]).to eq(resolved)

      expect { resolve }.not_to output.to_stdout
      expect(described_class).to have_received(:resolve_with_bundler).once
      expect(described_class).to have_received(:activate_resolved).with(gems_path, resolved).twice

      bundle_specs["rack"] = "3.2.0"
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(Dir["#{gems_path}/resolved-*.json"].size).to eq(2)
      expect(described_class).to have_received(:resolve_with_bundler).twice
    end

    it "resolves again when the plugin's Gemfile.lock changes" do
      write_gemfile_lock
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout

      write_gemfile_lock(markbridge_version: "0.4.4")
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(Dir["#{gems_path}/resolved-*.json"].size).to eq(2)
      expect(described_class).to have_received(:install_resolved).with(
        gems_path,
        [
          { "name" => "markbridge", "version" => "0.4.4", "dependencies" => ["zeitwerk-lite"] },
          { "name" => "zeitwerk-lite", "version" => "1.0.0", "dependencies" => [] },
        ],
      )
    end

    it "takes the lockfile from the given path" do
      write_gemfile_lock
      FileUtils.mkdir_p(File.join(plugin_dir, "deps"))
      other_lock_path = File.join(plugin_dir, "deps", "Gemfile.lock")
      File.rename(lock_path, other_lock_path)

      expect { described_class.resolve(plugin_path, requirements, lockfile: other_lock_path) }.to(
        output(/Resolved 2 gems/).to_stdout,
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
    end

    it "resolves again when the manifest does not parse" do
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      manifest_path = Dir["#{gems_path}/resolved-*.json"].first
      File.write(manifest_path, "{ half written")

      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(JSON.parse(File.read(manifest_path))["gems"]).to eq(resolved)
      expect(Dir["#{gems_path}/*.tmp"]).to be_empty
    end

    it "does not resolve when another process wrote the manifest while it waited for the lock" do
      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      manifest_path = Dir["#{gems_path}/resolved-*.json"].first
      manifest = File.read(manifest_path)
      File.delete(manifest_path)

      # Test seam: the other process finishes before this one gets the lock.
      allow(described_class).to receive(:with_resolve_lock) do |&block|
        File.write(manifest_path, manifest)
        block.call
      end

      expect { resolve }.not_to output.to_stdout
      expect(described_class).to have_received(:resolve_with_bundler).once
      expect(described_class).to have_received(:activate_resolved).with(gems_path, resolved).twice
    end
  end

  describe ".resolve_with_bundler" do
    let(:bundle_specs) { { "pg" => "1.6.3", "rack" => "3.1.0" } }
    let(:unpinnable) { { "raindrops" => "git" } }
    let(:requirements) { { "markbridge" => ">= 0.4.0", "rack" => ">= 3" } }
    let(:gemfile) { +"" }
    let(:locked_specs) { +<<~SPECS }
      markbridge (0.4.3)
        rack (>= 3)
        raindrops (>= 0.20)
      pg (1.6.3)
      rack (3.1.0)
      raindrops (0.20.1)
    SPECS

    before do
      allow(Open3).to receive(:capture2e) do |env, *|
        gemfile_path = env["BUNDLE_GEMFILE"]
        gemfile << File.read(gemfile_path)
        File.write("#{gemfile_path}.lock", <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
          #{locked_specs.gsub(/^/, "    ")}
          PLATFORMS
            ruby

          DEPENDENCIES
            markbridge (>= 0.4.0)
            pg (= 1.6.3)
            rack (= 3.1.0)
        LOCK
        ["", instance_double(Process::Status, success?: true)]
      end
    end

    it "pins every gem of the bundle, also those the plugin requires" do
      # raindrops is the application's git gem, already activated
      expect(
        described_class.resolve_with_bundler(plugin_name, bundle_specs, unpinnable, requirements),
      ).to eq([{ "name" => "markbridge", "version" => "0.4.3", "dependencies" => [] }])
      expect(gemfile).to eq(<<~GEMFILE)
        source "https://rubygems.org"
        gem "pg", "= 1.6.3"
        gem "rack", "= 3.1.0"
        gem "markbridge", ">= 0.4.0"
      GEMFILE
    end

    it "takes the dependencies of the lock entry for the local platform" do
      locked_specs << <<~SPECS
        mini_portile2 (2.8.9)
        nokogiri (1.18.0)
          mini_portile2 (~> 2.8)
          racc (~> 1.4)
        nokogiri (1.18.0-#{Gem::Platform.local})
          racc (~> 1.4)
        racc (1.8.1)
      SPECS

      expect(
        described_class.resolve_with_bundler(plugin_name, bundle_specs, unpinnable, requirements),
      ).to include({ "name" => "nokogiri", "version" => "1.18.0", "dependencies" => ["racc"] })
    end
  end

  describe ".bundle_specs_by_name" do
    it "leaves out bundler itself" do
      specs = [
        double(
          name: "pg",
          version: Gem::Version.new("1.6.3"),
          source: Bundler::Source::Rubygems.new,
        ),
        double(
          name: "bundler",
          version: Gem::Version.new("4.0.11"),
          source: Bundler::Source::Metadata.new,
        ),
      ]
      allow(Bundler).to receive(:load).and_return(instance_double(Bundler::Runtime, specs:))

      expect(described_class.bundle_specs_by_name).to eq("pg" => "1.6.3")
    end
  end

  describe ".activated_plugin_gems" do
    it "takes activated gems outside the bundle, default gems included, but not bundler" do
      allow(Gem).to receive(:loaded_specs).and_return(
        "pg" => double(version: Gem::Version.new("1.6.3")),
        "raindrops" => double(version: Gem::Version.new("0.20.1")),
        "pathname" => double(version: Gem::Version.new("0.4.0")),
        "bundler" => double(version: Gem::Version.new("4.0.11")),
      )

      expect(
        described_class.activated_plugin_gems({ "pg" => "1.6.3" }, { "raindrops" => "git" }),
      ).to eq("pathname" => "0.4.0")
    end
  end

  describe ".gemfile_requirements" do
    let(:gemfile_path) { File.join(plugin_dir, "Gemfile") }

    it "takes the Gemfile's dependencies with their requirements, without the skipped groups" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "markbridge", "~> 0.4", ">= 0.4.1"
        gem "samovar"
        group :development do
          gem "syntax_tree"
        end
        gem "rspec", group: :test
        gem "mocha", groups: %i[test tooling]
      GEMFILE

      expect(described_class.gemfile_requirements(gemfile_path)).to eq(
        "markbridge" => ["~> 0.4", ">= 0.4.1"],
        "samovar" => [">= 0"],
        "mocha" => [">= 0"],
      )
      # mocha stays: only one of its groups is skipped
      expect(described_class.gemfile_requirements(gemfile_path, without: %i[tooling])).to eq(
        "markbridge" => ["~> 0.4", ">= 0.4.1"],
        "samovar" => [">= 0"],
        "syntax_tree" => [">= 0"],
        "rspec" => [">= 0"],
        "mocha" => [">= 0"],
      )
    end

    it "takes a path gem's runtime dependencies instead of the path gem" do
      FileUtils.mkdir_p(File.join(plugin_dir, "engine"))
      File.write(File.join(plugin_dir, "engine", "engine.gemspec"), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "engine"
          s.version = "0.0.1"
          s.summary = "test"
          s.authors = ["test"]
          s.add_dependency "extralite-bundle", ">= 3.1"
          s.add_dependency "markbridge"
          s.add_dependency "helper"
          s.add_development_dependency "rspec"
        end
      GEMSPEC
      FileUtils.mkdir_p(File.join(plugin_dir, "helper"))
      File.write(File.join(plugin_dir, "helper", "helper.gemspec"), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "helper"
          s.version = "0.0.1"
          s.summary = "test"
          s.authors = ["test"]
          s.add_dependency "zeitwerk"
        end
      GEMSPEC
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "engine", path: "engine"
        gem "helper", path: "helper"
        gem "markbridge", "~> 0.4"
      GEMFILE

      expect(described_class.gemfile_requirements(gemfile_path)).to eq(
        "markbridge" => ["~> 0.4"],
        "extralite-bundle" => [">= 3.1"],
        "zeitwerk" => [">= 0"],
      )
    end

    it "merges a path gem's constraint with the Gemfile's" do
      FileUtils.mkdir_p(File.join(plugin_dir, "engine"))
      File.write(File.join(plugin_dir, "engine", "engine.gemspec"), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "engine"
          s.version = "0.0.1"
          s.summary = "test"
          s.authors = ["test"]
          s.add_dependency "markbridge", ">= 0.4.2"
        end
      GEMSPEC
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "engine", path: "engine"
        gem "markbridge", "~> 0.4"
      GEMFILE

      expect(described_class.gemfile_requirements(gemfile_path)).to eq(
        "markbridge" => ["~> 0.4", ">= 0.4.2"],
      )
    end

    it "skips dependencies for other platforms" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "markbridge"
        gem "tzinfo-data", platforms: %i[jruby]
      GEMFILE

      expect(described_class.gemfile_requirements(gemfile_path)).to eq("markbridge" => [">= 0"])
    end

    it "refuses a gem from git" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "markbridge", git: "https://example.com/markbridge.git"
      GEMFILE

      expect { described_class.gemfile_requirements(gemfile_path) }.to raise_error(
        RuntimeError,
        "markbridge comes from git in #{gemfile_path}; the resolver installs from rubygems.org only",
      )
    end

    it "refuses a gem from another gem source" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "markbridge", source: "https://gems.example.com"
      GEMFILE

      expect { described_class.gemfile_requirements(gemfile_path) }.to raise_error(
        RuntimeError,
        "markbridge comes from https://gems.example.com/ in #{gemfile_path}; " \
          "the resolver installs from rubygems.org only",
      )
    end

    it "refuses a gem from a source block" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        source "https://gems.example.com" do
          gem "markbridge"
        end
      GEMFILE

      expect { described_class.gemfile_requirements(gemfile_path) }.to raise_error(
        RuntimeError,
        %r{markbridge comes from https://gems.example.com/ in},
      )
    end

    it "skips dependencies bundler would not install" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        gem "markbridge"
        install_if(-> { false }) { gem "samovar" }
      GEMFILE

      expect(described_class.gemfile_requirements(gemfile_path)).to eq("markbridge" => [">= 0"])
    end
  end

  describe "Plugin::Instance#gemfile" do
    it "takes the lockfile next to the Gemfile" do
      plugin = Plugin::Instance.new(nil, plugin_path)
      gemfile_path = File.join(plugin_dir, "deps", "Gemfile")
      allow(described_class).to receive(:gemfile_requirements).and_return("markbridge" => ">= 0.4")
      allow(described_class).to receive(:resolve)

      plugin.gemfile("deps/Gemfile")

      expect(described_class).to have_received(:gemfile_requirements).with(
        gemfile_path,
        without: %i[development test],
      )
      expect(described_class).to have_received(:resolve).with(
        plugin_path,
        { "markbridge" => ">= 0.4" },
        lockfile: "#{gemfile_path}.lock",
      )
    end
  end

  describe ".install_resolved" do
    let(:gems) { [{ "name" => "markbridge", "version" => "0.4.3", "dependencies" => [] }] }

    def status(success)
      instance_double(Process::Status, success?: success)
    end

    it "installs with gem install and checks the exit status" do
      allow(Open3).to receive(:capture2e).and_return(["Successfully installed", status(true)])

      expect { described_class.install_resolved(gems_path, gems) }.to output(
        /gem install markbridge -v 0.4.3 -i #{Regexp.escape(gems_path)}/,
      ).to_stdout
      expect(Open3).to have_received(:capture2e).with(
        "gem",
        "install",
        "markbridge",
        "-v",
        "0.4.3",
        "-i",
        gems_path,
        "--no-document",
        "--ignore-dependencies",
        "--no-user-install",
      )
    end

    it "raises when gem install fails" do
      allow(Open3).to receive(:capture2e).and_return(["ERROR: no network", status(false)])

      expect {
        expect { described_class.install_resolved(gems_path, gems) }.to output(
          /ERROR: no network/,
        ).to_stdout
      }.to raise_error("Installing plugin gem markbridge 0.4.3 failed, see the output above")
    end

    it "skips a gem that is already installed" do
      FileUtils.mkdir_p("#{gems_path}/specifications")
      File.write("#{gems_path}/specifications/markbridge-0.4.3.gemspec", "")
      allow(Open3).to receive(:capture2e)

      described_class.install_resolved(gems_path, gems)

      expect(Open3).not_to have_received(:capture2e)
    end
  end

  describe ".activate_resolved" do
    let(:activated) { [] }

    def install_fake_gem(name, version)
      FileUtils.mkdir_p("#{gems_path}/specifications")
      File.write("#{gems_path}/specifications/#{name}-#{version}.gemspec", "")
    end

    before do
      allow(Gem::Specification).to receive(:load) do |file|
        spec = instance_double(Gem::Specification)
        allow(spec).to receive(:activate) { activated << File.basename(file, ".gemspec") }
        spec
      end
    end

    after { Gem.path.delete(gems_path) }

    it "activates dependencies before the gems that need them" do
      install_fake_gem("app-gem", "1.0.0")
      install_fake_gem("middle-gem", "2.0.0")
      install_fake_gem("leaf-gem", "3.0.0")

      described_class.activate_resolved(
        gems_path,
        [
          { "name" => "app-gem", "version" => "1.0.0", "dependencies" => %w[middle-gem leaf-gem] },
          { "name" => "middle-gem", "version" => "2.0.0", "dependencies" => ["leaf-gem"] },
          { "name" => "leaf-gem", "version" => "3.0.0", "dependencies" => [] },
        ],
      )

      expect(activated).to eq(%w[leaf-gem-3.0.0 middle-gem-2.0.0 app-gem-1.0.0])
      expect(Gem.path).to include(gems_path)
    end

    it "refuses circular dependencies" do
      gems = [
        { "name" => "a-gem", "version" => "1.0.0", "dependencies" => ["b-gem"] },
        { "name" => "b-gem", "version" => "1.0.0", "dependencies" => ["a-gem"] },
      ]

      expect { described_class.activate_resolved(gems_path, gems) }.to raise_error(
        /Circular plugin gem dependencies/,
      )
      expect(activated).to be_empty
    end

    it "fails when a resolved gem is not installed" do
      gems = [{ "name" => "missing-gem", "version" => "1.0.0", "dependencies" => [] }]

      expect { described_class.activate_resolved(gems_path, gems) }.to raise_error(
        "Resolved plugin gem missing-gem 1.0.0 is not installed",
      )
    end
  end
end
