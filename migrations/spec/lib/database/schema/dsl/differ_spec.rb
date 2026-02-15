# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Differ do
  after { Migrations::Database::Schema.reset! }

  let(:connection) { double("database_connection") } # rubocop:disable RSpec/VerifiedDoubles

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
    allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)
  end

  describe "#diff" do
    it "returns empty result when everything matches" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) { include :id, :username }

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id username] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.unknown_tables).to be_empty
      expect(result.missing_tables).to be_empty
      expect(result.stale_ignored_tables).to be_empty
      expect(result.table_diffs).to be_empty
    end

    it "detects unknown tables" do
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

      names = result.unknown_tables.map(&:name)
      expect(names).to contain_exactly("comments", "posts")
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

      names = result.unknown_tables.map(&:name)
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

    it "detects unknown columns" do
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
      names = diff.unknown_columns.map(&:name)
      expect(names).to contain_exactly("created_at", "email")
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
        ignore :old_column, "removed in migration"
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

    it "accounts for added columns in effective columns" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        add_column :display_name, :text
      end

      stub_database(connection, db_tables: %i[users], table_columns: { users: %i[id username] })

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs).to be_empty
    end

    it "returns no table diff when columns match exactly" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) do
        include :id, :username
        ignore :legacy_col, "deprecated"
      end

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username legacy_col],
        },
      )

      result = described_class.new(Migrations::Database::Schema).diff

      expect(result.table_diffs).to be_empty
    end

    it "handles tables with no explicit include (all columns mode)" do
      stub_plugin_manifest_unavailable

      Migrations::Database::Schema.table(:users) {}

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: %i[id username email],
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
  end
end
