# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::PluginManifest do
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

  describe "#initialize" do
    it "defaults plugins_path to the Rails plugins directory" do
      rails = class_double("Rails", root: Pathname.new("/app"))
      stub_const("Rails", rails)

      manifest = described_class.new(manifest_path:)

      expect(manifest.instance_variable_get(:@plugins_path)).to eq("/app/plugins")
    end

    it "uses the given plugins_path when provided" do
      manifest = build_manifest

      expect(manifest.instance_variable_get(:@plugins_path)).to eq(plugins_path)
    end

    it "loads the manifest data from file when the file exists" do
      write_manifest(
        { "plugins" => { "chat" => { "tables" => %w[chat_channels], "columns" => {} } } },
      )

      expect(build_manifest.tables_for_plugin("chat")).to eq(%w[chat_channels])
    end

    it "falls back to empty data when the manifest file does not exist" do
      manifest = build_manifest

      expect(manifest.all_plugin_names).to eq([])
      expect(manifest.failed_plugins).to eq([])
      expect(manifest.table_count).to eq(0)
    end

    it "falls back to empty data when the file contains no data" do
      File.write(manifest_path, "")

      manifest = build_manifest

      expect(manifest.all_plugin_names).to eq([])
      expect(manifest.table_count).to eq(0)
    end
  end

  describe "#available?" do
    it "returns true when the manifest file exists" do
      write_manifest({ "plugins" => {} })

      expect(build_manifest.available?).to be true
    end

    it "returns false when the manifest file does not exist" do
      expect(build_manifest.available?).to be false
    end
  end

  describe "#fresh?" do
    it "returns false when manifest file does not exist" do
      expect(build_manifest.fresh?).to be false
    end

    it "returns true when checksums match" do
      checksums =
        Migrations::Tooling::Schema::DSL::PluginIntrospector.compute_checksums(plugins_path)

      write_manifest({ "plugins" => {}, "plugin_checksums" => checksums })

      expect(build_manifest.fresh?).to be true
    end

    it "returns false when the stored checksums key is missing" do
      write_manifest({ "plugins" => {} })

      expect(build_manifest.fresh?).to be false
    end

    it "returns false when the stored checksums are nil" do
      write_manifest({ "plugins" => {}, "plugin_checksums" => nil })

      expect(build_manifest.fresh?).to be false
    end

    it "returns false when the stored checksums do not match the computed ones" do
      write_manifest(
        { "plugins" => {}, "plugin_checksums" => { "chat" => "stale-checksum" } },
      )

      expect(build_manifest.fresh?).to be false
    end

    it "treats an empty manifest file as fresh against an empty plugins directory" do
      # An empty file exists, so the manifest is available but parses to nil and
      # falls back to empty_data. Its empty checksums hash must match the empty
      # checksums computed for a plugins directory with no plugins.
      File.write(manifest_path, "")

      expect(build_manifest.fresh?).to be true
    end
  end

  describe "#incomplete?" do
    it "returns true when there are failed plugins" do
      write_manifest({ "plugins" => {}, "failed_plugins" => %w[chat] })

      expect(build_manifest.incomplete?).to be true
    end

    it "returns false when there are no failed plugins" do
      write_manifest({ "plugins" => {}, "failed_plugins" => [] })

      expect(build_manifest.incomplete?).to be false
    end
  end

  describe "#failed_plugins" do
    it "returns the list of failed plugins" do
      write_manifest({ "plugins" => {}, "failed_plugins" => %w[chat poll] })

      expect(build_manifest.failed_plugins).to eq(%w[chat poll])
    end

    it "returns an empty array when the key is missing" do
      write_manifest({ "plugins" => {} })

      expect(build_manifest.failed_plugins).to eq([])
    end

    it "wraps a single non-array value into an array" do
      write_manifest({ "plugins" => {}, "failed_plugins" => "chat" })

      expect(build_manifest.failed_plugins).to eq(%w[chat])
    end
  end

  describe "#all_plugin_names" do
    it "returns the plugin names sorted alphabetically" do
      write_manifest(
        {
          "plugins" => {
            "poll" => {
            },
            "chat" => {
            },
            "discourse-ai" => {
            },
          },
        },
      )

      expect(build_manifest.all_plugin_names).to eq(%w[chat discourse-ai poll])
    end

    it "returns an empty array when there are no plugins" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.all_plugin_names).to eq([])
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

    it "coerces a symbol table name to a string before lookup" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels],
              "columns" => {
              },
            },
          },
        },
      )

      expect(build_manifest.plugin_for_table(:chat_channels)).to eq("chat")
    end

    it "returns nil when the manifest has no plugins key" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.plugin_for_table("chat_channels")).to be_nil
    end

    it "handles plugins that have no tables key" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "columns" => {
                "users" => %w[chat_status],
              },
            },
          },
        },
      )

      expect(build_manifest.plugin_for_table("chat_channels")).to be_nil
    end

    it "memoizes the reverse index after the first lookup" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels],
            },
          },
        },
      )

      manifest = build_manifest
      expect(manifest.plugin_for_table("chat_channels")).to eq("chat")

      # Mutating the underlying data after the index is built must not change the
      # already-computed lookups; the second call returns the cached value.
      manifest.instance_variable_get(:@data)["plugins"]["chat"]["tables"] = %w[other_table]
      expect(manifest.plugin_for_table("chat_channels")).to eq("chat")
      expect(manifest.plugin_for_table("other_table")).to be_nil
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

    it "coerces symbol table and column names to strings before lookup" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => [],
              "columns" => {
                "user_options" => %w[chat_enabled],
              },
            },
          },
        },
      )

      expect(build_manifest.plugin_for_column(:user_options, :chat_enabled)).to eq("chat")
    end

    it "handles plugins that have no columns key" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels],
            },
          },
        },
      )

      expect(build_manifest.plugin_for_column("user_options", "chat_enabled")).to be_nil
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

    it "returns an empty array for an unknown plugin" do
      write_manifest({ "plugins" => {} })

      expect(build_manifest.tables_for_plugin("chat")).to eq([])
    end

    it "returns an empty array when the manifest has no plugins key" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.tables_for_plugin("chat")).to eq([])
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

    it "coerces a symbol table name to a string before lookup" do
      cols = build_manifest.columns_for_plugin("chat", table: :user_options)
      expect(cols).to eq(%w[chat_enabled chat_sound])
    end

    it "returns an empty array for a table that has no columns" do
      cols = build_manifest.columns_for_plugin("chat", table: "topics")
      expect(cols).to eq([])
    end

    it "normalizes underscored symbol names to hyphenated manifest keys" do
      write_manifest(
        {
          "plugins" => {
            "discourse-ai" => {
              "tables" => [],
              "columns" => {
                "posts" => %w[ai_summary],
              },
            },
          },
        },
      )

      expect(build_manifest.columns_for_plugin(:discourse_ai)).to eq(
        { "posts" => %w[ai_summary] },
      )
    end

    it "returns an empty hash for an unknown plugin" do
      expect(build_manifest.columns_for_plugin("poll")).to eq({})
    end

    it "returns an empty hash when the manifest has no plugins key" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.columns_for_plugin("chat")).to eq({})
    end

    it "returns an empty array for a table of an unknown plugin" do
      expect(build_manifest.columns_for_plugin("poll", table: "polls")).to eq([])
    end
  end

  describe "#table_count" do
    it "sums the number of tables across all plugins" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels chat_messages],
            },
            "poll" => {
              "tables" => %w[polls],
            },
          },
        },
      )

      expect(build_manifest.table_count).to eq(3)
    end

    it "treats a plugin without a tables key as contributing zero tables" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[chat_channels],
            },
            "poll" => {
            },
          },
        },
      )

      expect(build_manifest.table_count).to eq(1)
    end

    it "returns zero when there are no plugins" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.table_count).to eq(0)
    end
  end

  describe "#column_count" do
    it "sums the number of columns across all plugins and tables" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "columns" => {
                "user_options" => %w[chat_enabled chat_sound],
                "users" => %w[chat_status],
              },
            },
            "poll" => {
              "columns" => {
                "posts" => %w[poll],
              },
            },
          },
        },
      )

      expect(build_manifest.column_count).to eq(4)
    end

    it "treats a plugin without a columns key as contributing zero columns" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "columns" => {
                "users" => %w[chat_status],
              },
            },
            "poll" => {
            },
          },
        },
      )

      expect(build_manifest.column_count).to eq(1)
    end

    it "returns zero when there are no plugins" do
      write_manifest({ "plugin_checksums" => {} })

      expect(build_manifest.column_count).to eq(0)
    end
  end

  describe "#regenerate!" do
    def stub_introspector(result)
      introspector = instance_double(Migrations::Tooling::Schema::DSL::PluginIntrospector)
      allow(introspector).to receive(:introspect).and_return(result)
      allow(Migrations::Tooling::Schema::DSL::PluginIntrospector).to receive(:new).and_return(
        introspector,
      )
      introspector
    end

    it "writes the manifest file when generated data matches the default empty state" do
      stable_data = {
        "plugins" => {
        },
        "plugin_checksums" => {
        },
        "failed_plugins" => [],
        "incomplete" => false,
      }

      stub_introspector(stable_data)

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

      stub_introspector(stable_data)

      build_manifest.regenerate!

      expect(File.mtime(manifest_path)).to eq(mtime_before)
    end

    it "passes the configured plugins_path to the introspector" do
      stub_introspector(
        { "plugins" => {}, "plugin_checksums" => {}, "failed_plugins" => [], "incomplete" => false },
      )

      build_manifest.regenerate!

      expect(Migrations::Tooling::Schema::DSL::PluginIntrospector).to have_received(:new).with(
        plugins_path: plugins_path,
      )
    end

    it "rewrites the file when the manifest content changed" do
      write_manifest(
        {
          "plugins" => {
            "chat" => {
              "tables" => %w[old_table],
            },
          },
          "plugin_checksums" => {
          },
          "failed_plugins" => [],
          "incomplete" => false,
        },
      )

      new_data = {
        "plugins" => {
          "chat" => {
            "tables" => %w[chat_channels],
          },
        },
        "plugin_checksums" => {
        },
        "failed_plugins" => [],
        "incomplete" => false,
      }
      stub_introspector(new_data)

      build_manifest.regenerate!

      expect(described_class.new(manifest_path:, plugins_path:).tables_for_plugin("chat")).to eq(
        %w[chat_channels],
      )
    end

    it "refreshes lookups against the regenerated data within the same instance" do
      new_data = {
        "plugins" => {
          "chat" => {
            "tables" => %w[chat_channels],
            "columns" => {
            },
          },
        },
        "plugin_checksums" => {
        },
        "failed_plugins" => [],
        "incomplete" => false,
      }
      stub_introspector(new_data)

      manifest = build_manifest
      expect(manifest.plugin_for_table("chat_channels")).to be_nil

      manifest.regenerate!

      expect(manifest.plugin_for_table("chat_channels")).to eq("chat")
    end

    it "creates the manifest directory and writes the exact formatted YAML" do
      nested_path = File.join(manifest_dir, "nested", "plugin_manifest.yml")
      data = {
        "plugins" => {
          "chat" => {
            "tables" => %w[chat_channels chat_messages],
            "columns" => {
              "users" => %w[chat_enabled],
            },
          },
        },
        "plugin_checksums" => {
          "chat" => "abc",
        },
        "failed_plugins" => %w[poll],
        "incomplete" => true,
      }

      introspector = instance_double(Migrations::Tooling::Schema::DSL::PluginIntrospector)
      allow(introspector).to receive(:introspect).and_return(data)
      allow(Migrations::Tooling::Schema::DSL::PluginIntrospector).to receive(:new).and_return(
        introspector,
      )

      described_class.new(manifest_path: nested_path, plugins_path:).regenerate!

      expect(File).to exist(nested_path)

      # The custom formatting drops the leading "---" document marker, uses an
      # indentation step of two spaces, and indents every sequence entry two
      # extra spaces so that "- item" lines sit under their key.
      expect(File.read(nested_path)).to eq(<<~YAML)
        plugins:
          chat:
            tables:
              - chat_channels
              - chat_messages
            columns:
              users:
                - chat_enabled
        plugin_checksums:
          chat: abc
        failed_plugins:
          - poll
        incomplete: true
      YAML
    end
  end
end
