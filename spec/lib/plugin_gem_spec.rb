# frozen_string_literal: true

RSpec.describe PluginGem do
  let(:plugin_dir) { Dir.mktmpdir("plugin-gem-spec") }
  let(:plugin_path) { File.join(plugin_dir, "plugin.rb") }
  let(:gems_path) { File.join(plugin_dir, "gems", RUBY_VERSION) }
  let(:lock_path) { File.join(plugin_dir, "plugin-gems.lock") }

  after { FileUtils.rm_rf(plugin_dir) }

  describe ".resolve" do
    let(:bundle_specs) { { "pg" => "1.6.3", "rack" => "3.1.0" } }
    let(:unpinnable) { { "raindrops" => "git" } }
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
      allow(described_class).to receive(:resolve_with_bundler).and_return(resolved)
      allow(described_class).to receive(:install_resolved)
      allow(described_class).to receive(:activate_resolved)
    end

    it "refuses a requirement the application's locked version cannot satisfy" do
      requirements["pg"] = ">= 2"
      File.write(lock_path, JSON.generate(resolved))

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin needs pg >= 2, but the application locks pg 1.6.3",
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
      expect(described_class).not_to have_received(:install_resolved)
    end

    it "refuses a requirement for a gem the application loads from git or a path" do
      requirements["raindrops"] = ">= 0.20"

      expect { resolve }.to raise_error(
        RuntimeError,
        "Plugin needs raindrops >= 0.20, but the application loads raindrops from git; " \
          "drop the requirement, the gem is already activated",
      )
      expect(described_class).not_to have_received(:resolve_with_bundler)
    end

    it "ignores plugin-gems.lock when it lists a gem the application loads from git" do
      stale = resolved + [{ "name" => "raindrops", "version" => "0.20.1", "dependencies" => [] }]
      File.write(lock_path, JSON.generate(stale))

      expect { resolve }.to output(
        /plugin-gems.lock ignored: raindrops is in the application's bundle/,
      ).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler)
      expect(described_class).to have_received(:install_resolved).with(gems_path, resolved)
    end

    it "uses plugin-gems.lock when it satisfies the requirements" do
      File.write(lock_path, JSON.generate(resolved))

      expect { resolve }.to output(/Resolved 2 gems/).to_stdout
      expect(described_class).not_to have_received(:resolve_with_bundler)
      expect(described_class).to have_received(:install_resolved).with(gems_path, resolved)
      expect(described_class).to have_received(:activate_resolved).with(gems_path, resolved)
    end

    it "ignores plugin-gems.lock when a locked version does not satisfy" do
      outdated = [{ "name" => "markbridge", "version" => "0.3.0", "dependencies" => [] }]
      File.write(lock_path, JSON.generate(outdated))

      expect { resolve }.to output(
        /plugin-gems.lock ignored: markbridge 0.3.0 does not satisfy >= 0.4.0/,
      ).to_stdout
      expect(described_class).to have_received(:resolve_with_bundler).with(
        bundle_specs,
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
