# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Differ do
  after { Migrations::Database::Schema.reset! }

  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  def mock_db_columns(names)
    names.map do |name|
      col = instance_double(ActiveRecord::ConnectionAdapters::Column)
      allow(col).to receive(:name).and_return(name.to_s)
      col
    end
  end

  def stub_database(connection, db_tables:, table_columns: {})
    allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)
    allow(connection).to receive(:tables).and_return(db_tables.map(&:to_s))

    table_columns.each do |table_name, columns|
      allow(connection).to receive(:columns).with(table_name.to_s).and_return(
        mock_db_columns(columns),
      )
    end
  end

  def stub_plugin_manifest_unavailable
    manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
    allow(manifest).to receive(:fresh?).and_return(false)
    allow(manifest).to receive(:available?).and_return(false)
    allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)
  end

  describe "#diff" do
    it "returns empty result when everything matches" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id, :username }

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id username] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.unconfigured_tables).to be_empty
      expect(result.missing_tables).to be_empty
      expect(result.stale_ignored_tables).to be_empty
      expect(result.table_diffs).to be_empty
    end

    it "detects unconfigured tables" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id }

      stub_database(
        connection,
        db_tables: %i[users posts comments],
        table_columns: {
          users: %i[id],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      names = result.unconfigured_tables.map(&:name)
      expect(names).to contain_exactly("comments", "posts")
    end

    it "does not report copy_structure_from source tables as unknown" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table :user_archive do
        copy_structure_from :users
        include :id
      end

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.unconfigured_tables).to be_empty
    end

    it "excludes ignored tables from unknown" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id }
      Migrations::Database::Schema.ignored { table :posts, "not needed" }

      stub_database(
        connection,
        db_tables: %i[users posts comments],
        table_columns: {
          users: %i[id],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      names = result.unconfigured_tables.map(&:name)
      expect(names).to contain_exactly("comments")
    end

    it "detects missing tables" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id }
      Migrations::Database::Schema.table(:posts) { include :id }

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id] })

      result = described_class.new(Migrations::Database::Schema).diff

      names = result.missing_tables.map(&:name)
      expect(names).to contain_exactly("posts")
    end

    it "does not report synthetic tables as missing" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:log_entries) do
        synthetic!
        add_column :created_at, :datetime
      end

      stub_database(connection, db_tables: [])

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.missing_tables).to be_empty
    end

    it "detects stale ignored tables" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.ignored do
        table :old_table, "removed"
        table :users, "still exists"
      end

      stub_database(connection, db_tables: %i[users])

      result = described_class.new(Migrations::Database::Schema).diff

      names = result.stale_ignored_tables.map(&:name)
      expect(names).to contain_exactly("old_table")
    end

    it "detects unconfigured columns" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id, :username }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username email created_at],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.table_name).to eq("users")
      names = diff.unconfigured_columns.map(&:name)
      expect(names).to contain_exactly("created_at", "email")
    end

    it "uses source table name when attributing unconfigured columns for copied tables" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:plugin_for_table).and_return(nil)
      allow(manifest).to receive(:plugin_for_column).with("users", "chat_enabled").and_return(
        "chat",
      )
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table :user_archive do
        copy_structure_from :users
        include :id, :username
      end

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username chat_enabled],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.table_name).to eq("user_archive")
      expect(diff.unconfigured_columns.map(&:name)).to eq(["chat_enabled"])
      expect(diff.unconfigured_columns.first.plugin).to eq("chat")
    end

    it "detects missing columns" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id, :username, :bio }

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id username] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      names = diff.missing_columns.map(&:name)
      expect(names).to contain_exactly("bio")
    end

    it "detects stale ignored columns" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        ignore :old_column, reason: "removed in migration"
      end

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id username] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      names = diff.stale_ignored_columns.map(&:name)
      expect(names).to contain_exactly("old_column")
    end

    it "accounts for globally ignored columns" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.conventions { ignore_columns :updated_at }
      Migrations::Database::Schema.table(:users) { include :id, :username }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username updated_at],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs).to be_empty
    end

    it "skips column diff for tables missing from database" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id, :nonexistent_col }

      stub_database(connection, db_tables: [])

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs).to be_empty
      expect(result.missing_tables.size).to eq(1)
    end

    it "excludes tables from ignored plugins" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("chat").and_return(
        %w[chat_channels chat_messages],
      )
      allow(manifest).to receive(:columns_for_plugin).and_return([])
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table(:users) { include :id }
      Migrations::Database::Schema.ignored { plugin :chat, "Not migrating" }

      stub_database(
        connection,
        db_tables: %i[users chat_channels chat_messages],
        table_columns: {
          users: %i[id],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.unconfigured_tables).to be_empty
    end

    it "auto-ignores columns from ignored plugins without ignore_plugin_columns!" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).and_return([])
      allow(manifest).to receive(:columns_for_plugin).with("chat", table: "users").and_return(
        %w[chat_enabled chat_sound],
      )
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table(:users) { include :id, :username }
      Migrations::Database::Schema.ignored { plugin :chat, "Not migrating" }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username chat_enabled chat_sound],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.unconfigured_columns).to be_empty
      expect(diff.auto_ignored_columns.map(&:name)).to contain_exactly("chat_enabled", "chat_sound")
    end

    it "ignore_plugin_columns! additionally ignores columns from non-ignored plugins" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[chat polls])
      allow(manifest).to receive(:columns_for_plugin).with("chat", table: "users").and_return(
        %w[chat_enabled],
      )
      allow(manifest).to receive(:columns_for_plugin).with("polls", table: "users").and_return(
        %w[polls_enabled],
      )
      allow(manifest).to receive(:plugin_for_column).and_return(nil)
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        ignore_plugin_columns!
      end
      Migrations::Database::Schema.ignored { plugin :chat, "Not migrating" }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username chat_enabled polls_enabled],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.unconfigured_columns).to be_empty
      expect(diff.auto_ignored_columns.map(&:name)).to contain_exactly(
        "chat_enabled",
        "polls_enabled",
      )
    end

    it "ignore_plugin_columns! with specific plugin names only ignores those plugins" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[polls discourse_ai])
      allow(manifest).to receive(:columns_for_plugin).with("polls", table: "users").and_return(
        %w[polls_enabled],
      )
      allow(manifest).to receive(:columns_for_plugin).with(
        "discourse_ai",
        table: "users",
      ).and_return(%w[ai_summary])
      allow(manifest).to receive(:plugin_for_column).and_return(nil)
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        ignore_plugin_columns! :polls
      end
      Migrations::Database::Schema.ignored { table :unused_table, "placeholder" }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username polls_enabled ai_summary],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.auto_ignored_columns.map(&:name)).to contain_exactly("polls_enabled")
      expect(diff.unconfigured_columns.map(&:name)).to contain_exactly("ai_summary")
    end

    it "normalizes underscored plugin filters for ignore_plugin_columns!" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[discourse-ai])
      allow(manifest).to receive(:columns_for_plugin).with(
        "discourse-ai",
        table: "users",
      ).and_return(%w[ai_summary])
      allow(manifest).to receive(:plugin_for_column).and_return(nil)
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        ignore_plugin_columns! :discourse_ai
      end
      Migrations::Database::Schema.ignored { table :unused_table, "placeholder" }

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username ai_summary],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs.size).to eq(1)
      diff = result.table_diffs.first
      expect(diff.auto_ignored_columns.map(&:name)).to contain_exactly("ai_summary")
      expect(diff.unconfigured_columns).to be_empty
    end
  end
end
