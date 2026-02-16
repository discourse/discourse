# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Scaffolder do
  after { Migrations::Database::Schema.reset! }

  let(:connection) { double("database_connection") } # rubocop:disable RSpec/VerifiedDoubles

  def mock_db_columns(columns_hash)
    columns_hash.map do |name, attrs|
      col = instance_double(ActiveRecord::ConnectionAdapters::Column)
      allow(col).to receive_messages(
        name: name.to_s,
        type: attrs[:type] || :text,
        null: attrs.fetch(:null, true),
        default: attrs[:default],
        limit: attrs[:limit],
      )
      col
    end
  end

  def mock_index(name:, columns:, unique: false, where: nil)
    idx = double("index_#{name}") # rubocop:disable RSpec/VerifiedDoubles
    allow(idx).to receive_messages(name:, columns:, unique:, where:)
    idx
  end

  def stub_database(connection, db_tables:, table_columns: {}, primary_keys: {}, indexes: {})
    allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)
    allow(connection).to receive(:tables).and_return(db_tables.map(&:to_s))

    table_columns.each do |table_name, columns|
      allow(connection).to receive(:columns).with(table_name.to_s).and_return(
        mock_db_columns(columns),
      )
    end

    primary_keys.each do |table_name, keys|
      allow(connection).to receive(:primary_keys).with(table_name.to_s).and_return(keys)
    end

    indexes.each do |table_name, idx_list|
      allow(connection).to receive(:indexes).with(table_name.to_s).and_return(idx_list)
    end
  end

  describe "#scaffold!" do
    it "generates a table config file" do
      Dir.mktmpdir do |tmpdir|
        config_path = File.join(tmpdir, "schema")
        allow(Migrations::Database::Schema).to receive(:config_path).with(any_args).and_return(
          config_path,
        )

        stub_database(
          connection,
          db_tables: %i[users],
          table_columns: {
            users: {
              id: {
                type: :integer,
              },
              username: {
                type: :text,
              },
              email: {
                type: :text,
              },
            },
          },
          primary_keys: {
            users: ["id"],
          },
          indexes: {
            users: [],
          },
        )

        schema = Migrations::Database::Schema
        path = described_class.new(schema, :users).scaffold!

        expect(File.exist?(path)).to be true

        content = File.read(path)
        expect(content).to include("table :users do")
        expect(content).to include("include :id, :username, :email")
      end
    end

    it "writes to the selected database config path" do
      Dir.mktmpdir do |tmpdir|
        allow(Migrations::Database::Schema).to receive(
          :config_path,
        ) do |database = :intermediate_db|
          File.join(tmpdir, "schema", database.to_s)
        end

        stub_database(
          connection,
          db_tables: %i[users],
          table_columns: {
            users: {
              id: {
                type: :integer,
              },
              username: {
                type: :text,
              },
            },
          },
          primary_keys: {
            users: ["id"],
          },
          indexes: {
            users: [],
          },
        )

        schema = Migrations::Database::Schema
        path = described_class.new(schema, :users, database: :archive_db).scaffold!

        expect(path).to include("/schema/archive_db/tables/users.rb")
        expect(
          File.exist?(File.join(tmpdir, "schema", "intermediate_db", "tables", "users.rb")),
        ).to be(false)
      end
    end

    it "includes composite primary keys" do
      Dir.mktmpdir do |tmpdir|
        config_path = File.join(tmpdir, "schema")
        allow(Migrations::Database::Schema).to receive(:config_path).with(any_args).and_return(
          config_path,
        )

        stub_database(
          connection,
          db_tables: %i[topic_tags],
          table_columns: {
            topic_tags: {
              topic_id: {
                type: :integer,
              },
              tag_id: {
                type: :integer,
              },
            },
          },
          primary_keys: {
            topic_tags: %w[topic_id tag_id],
          },
          indexes: {
            topic_tags: [],
          },
        )

        schema = Migrations::Database::Schema
        path = described_class.new(schema, :topic_tags).scaffold!

        content = File.read(path)
        expect(content).to include("primary_key :topic_id, :tag_id")
      end
    end

    it "includes indexes" do
      Dir.mktmpdir do |tmpdir|
        config_path = File.join(tmpdir, "schema")
        allow(Migrations::Database::Schema).to receive(:config_path).with(any_args).and_return(
          config_path,
        )

        idx =
          mock_index(name: "idx_users_username", columns: %w[username], unique: true, where: nil)

        stub_database(
          connection,
          db_tables: %i[users],
          table_columns: {
            users: {
              id: {
                type: :integer,
              },
              username: {
                type: :text,
              },
            },
          },
          primary_keys: {
            users: ["id"],
          },
          indexes: {
            users: [idx],
          },
        )

        schema = Migrations::Database::Schema
        path = described_class.new(schema, :users).scaffold!

        content = File.read(path)
        expect(content).to include("unique_index :username, name: :idx_users_username")
      end
    end

    it "raises when table does not exist" do
      stub_database(connection, db_tables: [])

      schema = Migrations::Database::Schema
      expect { described_class.new(schema, :nonexistent).scaffold! }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /does not exist/,
      )
    end

    it "raises when config file already exists" do
      Dir.mktmpdir do |tmpdir|
        config_path = File.join(tmpdir, "schema")
        tables_dir = File.join(config_path, "tables")
        FileUtils.mkdir_p(tables_dir)
        File.write(File.join(tables_dir, "users.rb"), "existing")

        allow(Migrations::Database::Schema).to receive(:config_path).with(any_args).and_return(
          config_path,
        )

        stub_database(
          connection,
          db_tables: %i[users],
          table_columns: {
            users: {
              id: {
                type: :integer,
              },
            },
          },
          primary_keys: {
            users: ["id"],
          },
          indexes: {
            users: [],
          },
        )

        schema = Migrations::Database::Schema
        expect { described_class.new(schema, :users).scaffold! }.to raise_error(
          Migrations::Database::Schema::ConfigError,
          /already exists/,
        )
      end
    end

    it "excludes globally ignored columns" do
      Dir.mktmpdir do |tmpdir|
        config_path = File.join(tmpdir, "schema")
        allow(Migrations::Database::Schema).to receive(:config_path).with(any_args).and_return(
          config_path,
        )

        Migrations::Database::Schema.conventions { ignore_columns :updated_at }

        stub_database(
          connection,
          db_tables: %i[users],
          table_columns: {
            users: {
              id: {
                type: :integer,
              },
              username: {
                type: :text,
              },
              updated_at: {
                type: :datetime,
              },
            },
          },
          primary_keys: {
            users: ["id"],
          },
          indexes: {
            users: [],
          },
        )

        schema = Migrations::Database::Schema
        path = described_class.new(schema, :users).scaffold!

        content = File.read(path)
        expect(content).to include(":id, :username")
        expect(content).not_to include("updated_at")
      end
    end
  end
end
