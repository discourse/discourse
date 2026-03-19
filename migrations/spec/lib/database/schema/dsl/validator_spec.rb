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

  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

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

      errors = described_class.new(schema).validate

      expect(errors).to be_an(Array)
      expect(errors).to be_empty
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/not configured or ignored.*comments.*posts/m))
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

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end

    it "detects source table not existing in database" do
      schema = build_schema(tables: { users: proc { include_all } })

      stub_database(connection, db_tables: [], table_columns: {})

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/source table 'users' does not exist/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/included columns do not exist.*nonexistent/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/database columns are not configured or ignored.*email/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/column option for 'ghost'.*does not exist/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/added column 'username' already exists/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/references unknown enum 'nonexistent_enum'/))
    end

    it "detects column type overrides referencing unknown enums" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id, :status
                column :status, :missing_enum
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
            status: {
              type: :text,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(
        match(/column 'status' type 'missing_enum' references unknown enum/),
      )
    end

    it "detects stale ignored columns" do
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/ignored column 'gone_column' does not exist.*stale/))
    end

    it "detects stale ignored tables" do
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/Ignored table 'deleted_table' does not exist.*stale/))
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

      errors = described_class.new(schema).validate
      expect(errors).to include(
        match(/index 'idx_missing' references columns not in configuration/),
      )
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

      stub_database(connection, db_tables: [], table_columns: {})

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(match(/source table 'users' does not exist in database/))
    end

    it "does not report copy_structure_from source tables as unconfigured" do
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
      )

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
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

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/primary key columns are not configured.*id/))
    end

    it "does not report plugin-ignored tables as unconfigured" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("chat").and_return(
        %w[chat_channels chat_messages],
      )
      allow(manifest).to receive(:columns_for_plugin).with("chat", table: "users").and_return([])
      allow(manifest).to receive(:plugin_for_table).with("users").and_return(nil)
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

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end

    it "detects tables that are both configured and ignored" do
      schema =
        build_schema(
          tables: {
            users: proc { include_all },
          },
          ignored: proc { table :users, "not needed" },
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

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/Table 'users' is both configured and ignored/))
    end

    it "detects source table belonging to an ignored plugin" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("chat").and_return(
        %w[chat_channels chat_messages],
      )
      allow(manifest).to receive(:plugin_for_table).with("chat_channels").and_return("chat")
      allow(manifest).to receive(:columns_for_plugin).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[chat])
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      schema =
        build_schema(
          tables: {
            chat_channels: proc { include_all },
          },
          ignored: proc { plugin :chat, "Not migrating" },
        )

      stub_database(
        connection,
        db_tables: %i[chat_channels chat_messages],
        table_columns: {
          chat_channels: {
            id: {
              type: :integer,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/belongs to ignored plugin 'chat'/))
    end

    it "normalizes underscored ignored plugin names for plugin-owned source tables" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("discourse-ai").and_return(%w[ai_tools])
      allow(manifest).to receive(:plugin_for_table).with("ai_tools").and_return("discourse-ai")
      allow(manifest).to receive(:columns_for_plugin).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[discourse-ai])
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      schema =
        build_schema(
          tables: {
            ai_tools: proc { include_all },
          },
          ignored: proc { plugin :discourse_ai, "Not migrating" },
        )

      stub_database(
        connection,
        db_tables: %i[ai_tools],
        table_columns: {
          ai_tools: {
            id: {
              type: :integer,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/belongs to ignored plugin 'discourse-ai'/))
    end

    it "detects column options on excluded columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                column :email, :text
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
            email: {
              type: :text,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/column option for 'email'.*excluded column/))
    end

    it "detects duplicate index names" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id, :username, :email
                index :username, name: :idx_users
                index :email, name: :idx_users
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
            email: {
              type: :text,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/duplicate index name 'idx_users'/))
    end

    it "detects included columns that are globally ignored without include!" do
      schema =
        build_schema(
          tables: {
            users: proc { include :id, :updated_at },
          },
          conventions: proc { ignore_columns :updated_at },
        )

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: {
            id: {
              type: :integer,
            },
            updated_at: {
              type: :datetime,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/included column 'updated_at' is globally ignored.*include!/))
    end

    it "allows include! to override globally ignored columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id, :updated_at
                include! :updated_at
              end,
          },
          conventions: proc { ignore_columns :updated_at },
        )

      stub_database(
        connection,
        db_tables: %i[users],
        table_columns: {
          users: {
            id: {
              type: :integer,
            },
            updated_at: {
              type: :datetime,
            },
          },
        },
      )

      errors = described_class.new(schema).validate
      expect(errors).not_to include(match(/globally ignored/))
    end
  end
end
