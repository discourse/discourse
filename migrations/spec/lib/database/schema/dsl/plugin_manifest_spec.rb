# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::PluginManifest do
  let(:manifest_dir) { Dir.mktmpdir("manifest") }
  let(:manifest_path) { File.join(manifest_dir, "plugin_manifest.yml") }
  let(:plugins_path) { Dir.mktmpdir("plugins") }

  after do
    FileUtils.rm_rf(manifest_dir)
    FileUtils.rm_rf(plugins_path)
  end

  def write_manifest(data)
    File.write(manifest_path, YAML.dump(data))
  end

  def build_manifest
    described_class.new(manifest_path:, plugins_path:)
  end

  describe "#fresh?" do
    it "returns false when manifest file does not exist" do
      expect(build_manifest.fresh?).to be false
    end

    it "returns true when checksums match" do
      checksums =
        Migrations::Database::Schema::DSL::PluginIntrospector.compute_checksums(plugins_path)

      write_manifest({ "plugins" => {}, "plugin_checksums" => checksums })

      expect(build_manifest.fresh?).to be true
    end
  end

  describe "#plugin_for_table" do
    it "returns the plugin that owns a table" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels chat_messages],
              "columns" => {
              },
            },
          },
          "plugin_checksums" => {
          },
        },
      )

      manifest = build_manifest
      expect(manifest.plugin_for_table("chat_channels")).to eq("chat")
      expect(manifest.plugin_for_table("chat_messages")).to eq("chat")
      expect(manifest.plugin_for_table("users")).to be_nil
    end
  end

  describe "#plugin_for_column" do
    it "returns the plugin that owns a column" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => [],
              "columns" => {
                "user_options" => %w[chat_enabled chat_sound],
              },
            },
          },
          "plugin_checksums" => {
          },
        },
      )

      manifest = build_manifest
      expect(manifest.plugin_for_column("user_options", "chat_enabled")).to eq("chat")
      expect(manifest.plugin_for_column("user_options", "chat_sound")).to eq("chat")
      expect(manifest.plugin_for_column("user_options", "email")).to be_nil
      expect(manifest.plugin_for_column("other_table", "chat_enabled")).to be_nil
    end
  end

  describe "#tables_for_plugin" do
    it "returns tables for a given plugin" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels chat_messages],
              "columns" => {
              },
            },
          },
          "plugin_checksums" => {
          },
        },
      )

      expect(build_manifest.tables_for_plugin("chat")).to eq(%w[chat_channels chat_messages])
    end

    it "normalizes underscored symbol names to hyphenated manifest keys" do
      write_manifest(
        {
          "plugins" => {
            "discourse-ai" => {
              "tables" => %w[ai_tools ai_personas],
              "columns" => {
              },
            },
          },
          "plugin_checksums" => {
          },
        },
      )

      expect(build_manifest.tables_for_plugin(:discourse_ai)).to eq(%w[ai_tools ai_personas])
    end
  end

  describe "#columns_for_plugin" do
    before do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => [],
              "columns" => {
                "user_options" => %w[chat_enabled chat_sound],
                "users" => %w[chat_status],
              },
            },
          },
          "plugin_checksums" => {
          },
        },
      )
    end

    it "returns all columns for a plugin" do
      cols = build_manifest.columns_for_plugin("chat")
      expect(cols).to eq(
        { "user_options" => %w[chat_enabled chat_sound], "users" => %w[chat_status] },
      )
    end

    it "returns columns for a specific table" do
      cols = build_manifest.columns_for_plugin("chat", table: "user_options")
      expect(cols).to eq(%w[chat_enabled chat_sound])
    end
  end

  describe "#regenerate!" do
    it "writes the manifest file when generated data matches the default empty state" do
      stable_data = {
        "plugins" => {
        },
        "plugin_checksums" => {
        },
        "failed_plugins" => [],
        "incomplete" => false,
      }

      introspector = instance_double(Migrations::Database::Schema::DSL::PluginIntrospector)
      allow(introspector).to receive(:introspect).and_return(stable_data)
      allow(Migrations::Database::Schema::DSL::PluginIntrospector).to receive(:new).and_return(
        introspector,
      )

      manifest = build_manifest
      manifest.regenerate!

      expect(File).to exist(manifest_path)
      expect(described_class.new(manifest_path:, plugins_path:).fresh?).to be true
    end

    it "does not rewrite file when manifest content is unchanged" do
      stable_data = {
        "plugins" => {
          "chat" => {
            "tables" => ["chat_channels"],
            "columns" => {
              "users" => ["chat_enabled"],
            },
          },
        },
        "plugin_checksums" => {
          "chat" => "def",
        },
        "failed_plugins" => [],
        "incomplete" => false,
      }

      write_manifest(stable_data)
      mtime_before = File.mtime(manifest_path)

      introspector = instance_double(Migrations::Database::Schema::DSL::PluginIntrospector)
      allow(introspector).to receive(:introspect).and_return(stable_data)
      allow(Migrations::Database::Schema::DSL::PluginIntrospector).to receive(:new).and_return(
        introspector,
      )

      build_manifest.regenerate!

      expect(File.mtime(manifest_path)).to eq(mtime_before)
    end
  end
end
