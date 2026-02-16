# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Validator do
  after { Migrations::Database::Schema.reset! }

  def build_schema(tables: {}, enums: {}, conventions: nil, ignored: nil)
    schema = Migrations::Database::Schema

    tables.each { |name, block| schema.table(name, &block) }
    enums.each { |name, block| schema.enum(name, &block) }
    schema.conventions(&conventions) if conventions
    schema.ignored(&ignored) if ignored

    schema
  end

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

  def stub_database(connection, db_tables: [], table_columns: {}, primary_keys: {})
    allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)
    allow(connection).to receive(:tables).and_return(db_tables.map(&:to_s))

    allow(connection).to receive(:primary_keys) do |table_name|
      primary_keys.fetch(table_name.to_sym) { primary_keys.fetch(table_name.to_s, []) }
    end

    table_columns.each do |table_name, columns|
      allow(connection).to receive(:columns).with(table_name.to_s).and_return(
        mock_db_columns(columns),
      )
    end
  end

  let(:connection) { double("database_connection") } # rubocop:disable RSpec/VerifiedDoubles

  describe "#validate" do
    it "returns no errors for a valid configuration" do
      schema = build_schema(tables: { users: proc { include :id, :username } })

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
            username: {
              type: :text,
              null: false,
            },
          },
        },
      )

      result = described_class.new(schema).validate

      expect(result).to be_a(Migrations::Database::Schema::DSL::ValidationResult)
      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
    end

    it "detects unconfigured tables in database" do
      schema = build_schema(tables: { users: proc { include_all } })

      stub_database(
        connection,
        db_tables: %i[users posts comments],
        table_columns: {
          users: {
            id: {
              type: :integer,
            },
          },
        },
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/not configured or ignored.*comments.*posts/m))
    end

    it "does not report ignored tables as unconfigured" do
      schema =
        build_schema(
          tables: {
            users: proc { include_all },
          },
          ignored: proc { table :posts, "not needed" },
        )

      stub_database(
        connection,
        db_tables: %i[users posts],
        table_columns: {
          users: {
            id: {
              type: :integer,
            },
          },
        },
      )

      result = described_class.new(schema).validate
      expect(result.errors).to be_empty
    end

    it "detects source table not existing in database" do
      schema = build_schema(tables: { users: proc { include_all } })

      stub_database(connection, db_tables: [], table_columns: {})

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/source table 'users' does not exist/))
    end

    it "detects included columns not existing in database" do
      schema = build_schema(tables: { users: proc { include :id, :nonexistent } })

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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/included columns do not exist.*nonexistent/))
    end

    it "detects database columns that are not configured or ignored" do
      schema = build_schema(tables: { users: proc { include :id, :username } })

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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(
        match(/database columns are not configured or ignored.*email/),
      )
    end

    it "detects column options referencing missing columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                column :ghost, :integer
              end,
          },
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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/column option for 'ghost'.*does not exist/))
    end

    it "detects added columns that already exist in database" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                add_column :username, :text
              end,
          },
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
          },
        },
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/added column 'username' already exists/))
    end

    it "detects added columns referencing unknown enums" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                add_column :status, :integer, enum: :nonexistent_enum
              end,
          },
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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/references unknown enum 'nonexistent_enum'/))
    end

    it "warns about stale ignored columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                ignore :gone_column, reason: "was removed"
              end,
          },
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
      )

      result = described_class.new(schema).validate
      expect(result.warnings).to include(
        match(/ignored column 'gone_column' does not exist.*stale/),
      )
      expect(result.errors).to be_empty
    end

    it "warns about stale ignored tables" do
      schema =
        build_schema(
          tables: {
            users: proc { include_all },
          },
          ignored: proc { table :deleted_table, "no longer exists" },
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
      )

      result = described_class.new(schema).validate
      expect(result.warnings).to include(
        match(/Ignored table 'deleted_table' does not exist.*stale/),
      )
      expect(result.errors).to be_empty
    end

    it "detects index columns not in configuration" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                index :missing_col, name: :idx_missing
              end,
          },
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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(
        match(/index 'idx_missing' references columns not in configuration/),
      )
    end

    it "validates a table with synthetic! and only add_columns" do
      schema =
        build_schema(
          tables: {
            log_entries:
              proc do
                synthetic!
                add_column :created_at, :datetime, required: true
                add_column :message, :text, required: true
              end,
          },
        )

      stub_database(connection, db_tables: [], table_columns: {})

      result = described_class.new(schema).validate
      expect(result.errors).to be_empty
    end

    it "validates copy_structure_from source table" do
      schema =
        build_schema(
          tables: {
            user_archive:
              proc do
                copy_structure_from :users
                include :id
              end,
          },
        )

      stub_database(connection, db_tables: %i[user_archive], table_columns: {})

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/source table 'users' does not exist/))
    end

    it "validates enums have values" do
      empty_enum = proc {}

      expect { build_schema(enums: { empty: empty_enum }) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /must define at least one value/,
      )
    end

    it "passes when index references added columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                add_column :new_col, :text
                index :new_col, name: :idx_new_col
              end,
          },
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
      )

      result = described_class.new(schema).validate
      expect(result.errors).to be_empty
    end

    it "detects when primary key columns are not configured" do
      schema = build_schema(tables: { users: proc { include :username } })

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
            username: {
              type: :text,
              null: false,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).validate
      expect(result.errors).to include(match(/primary key columns are not configured.*id/))
    end

    it "does not report plugin-ignored tables as unconfigured" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("chat").and_return(
        %w[chat_channels chat_messages],
      )
      allow(manifest).to receive(:columns_for_plugin).with("chat", table: "users").and_return([])
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      schema =
        build_schema(
          tables: {
            users: proc { include_all },
          },
          ignored: proc { plugin :chat, "Not migrating" },
        )

      stub_database(
        connection,
        db_tables: %i[users chat_channels chat_messages],
        table_columns: {
          users: {
            id: {
              type: :integer,
            },
          },
        },
      )

      result = described_class.new(schema).validate
      expect(result.errors).to be_empty
    end
  end
end
