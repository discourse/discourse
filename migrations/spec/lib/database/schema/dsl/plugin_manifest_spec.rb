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

  describe "#available?" do
    it "returns false when manifest file does not exist" do
      expect(build_manifest.available?).to be false
    end

    it "returns true when manifest file exists" do
      write_manifest({ "plugins" => {} })
      expect(build_manifest.available?).to be true
    end
  end

  describe "#fresh?" do
    it "returns false when manifest file does not exist" do
      expect(build_manifest.fresh?).to be false
    end

    it "returns false when migration_state is missing" do
      write_manifest({ "plugins" => {} })
      expect(build_manifest.fresh?).to be false
    end

    it "returns true when checksums match" do
      introspector = Migrations::Database::Schema::DSL::PluginIntrospector.new(plugins_path:)
      checksums = introspector.compute_all_checksums

      write_manifest({ "plugins" => {}, "migration_state" => checksums })

      expect(build_manifest.fresh?).to be true
    end

    it "returns false when core checksum differs" do
      write_manifest(
        { "plugins" => {}, "migration_state" => { "core" => "stale_checksum", "plugins" => {} } },
      )

      expect(build_manifest.fresh?).to be false
    end

    it "returns false when plugin checksum differs" do
      plugin_dir = File.join(plugins_path, "chat", "db", "migrate")
      FileUtils.mkdir_p(plugin_dir)
      File.write(File.join(plugin_dir, "001_create_chat.rb"), "class CreateChat; end")

      introspector = Migrations::Database::Schema::DSL::PluginIntrospector.new(plugins_path:)
      checksums = introspector.compute_all_checksums
      checksums["plugins"]["chat"] = "stale_checksum"

      write_manifest({ "plugins" => {}, "migration_state" => checksums })

      expect(build_manifest.fresh?).to be false
    end

    it "returns false when manifest is marked incomplete due failed plugins" do
      introspector = Migrations::Database::Schema::DSL::PluginIntrospector.new(plugins_path:)
      checksums = introspector.compute_all_checksums

      write_manifest(
        {
          "plugins" => {
          },
          "migration_state" => checksums,
          "failed_plugins" => ["chat"],
          "incomplete" => true,
        },
      )

      expect(build_manifest.fresh?).to be false
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
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

  describe "#all_plugin_names" do
    it "returns sorted plugin names" do
      write_manifest(
        {
          "plugins" => {
            "polls" => {
              "tables" => [],
              "columns" => {
              },
            },
            "chat" => {
              "tables" => [],
              "columns" => {
              },
            },
          },
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
          },
        },
      )

      expect(build_manifest.all_plugin_names).to eq(%w[chat polls])
    end

    it "returns empty array when no manifest" do
      expect(build_manifest.all_plugin_names).to eq([])
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
          },
        },
      )

      expect(build_manifest.tables_for_plugin("chat")).to eq(%w[chat_channels chat_messages])
    end

    it "returns empty array for unknown plugin" do
      write_manifest({ "plugins" => {}, "migration_state" => { "core" => "abc", "plugins" => {} } })

      expect(build_manifest.tables_for_plugin("nonexistent")).to eq([])
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
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

    it "returns empty array for unknown table" do
      cols = build_manifest.columns_for_plugin("chat", table: "nonexistent")
      expect(cols).to eq([])
    end
  end

  describe "#table_count" do
    it "counts tables across all plugins" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels chat_messages],
              "columns" => {
              },
            },
            "polls" => {
              "tables" => %w[polls],
              "columns" => {
              },
            },
          },
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
          },
        },
      )

      expect(build_manifest.table_count).to eq(3)
    end
  end

  describe "#column_count" do
    it "counts columns across all plugins" do
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
          "migration_state" => {
            "core" => "abc",
            "plugins" => {
            },
          },
        },
      )

      expect(build_manifest.column_count).to eq(3)
    end
  end
end
