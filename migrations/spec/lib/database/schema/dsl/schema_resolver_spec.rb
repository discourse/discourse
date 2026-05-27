# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::SchemaResolver do
  after { Migrations::Database::Schema.reset! }

  def build_schema(tables: {}, enums: {}, conventions: nil)
    schema = Migrations::Database::Schema

    tables.each { |name, block| schema.table(name, &block) }

    enums.each { |name, block| schema.enum(name, &block) }

    schema.conventions(&conventions) if conventions

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

  def stub_database(connection, table_columns: {}, primary_keys: {})
    allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)

    table_columns.each do |table_name, columns|
      allow(connection).to receive(:columns).with(table_name.to_s).and_return(
        mock_db_columns(columns),
      )
    end

    primary_keys.each do |table_name, keys|
      allow(connection).to receive(:primary_keys).with(table_name.to_s).and_return(keys)
    end
  end

  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  describe "#resolve" do
    it "resolves a simple table with all DB columns" do
      schema = build_schema(tables: { users: proc { include_all } })

      stub_database(
        connection,
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
            email: {
              type: :text,
              null: true,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve

      expect(result).to be_a(Migrations::Database::Schema::Definition)
      expect(result.tables.size).to eq(1)

      table = result.tables.first
      expect(table.name).to eq("users")
      expect(table.columns.size).to eq(3)
      expect(table.primary_key_column_names).to eq(["id"])
    end

    it "resolves only included columns" do
      schema = build_schema(tables: { users: proc { include :id, :username } })

      stub_database(
        connection,
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
            email: {
              type: :text,
              null: true,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      expect(table.columns.map(&:name)).to contain_exactly("id", "username")
    end

    it "applies conventions for name and type" do
      schema =
        build_schema(
          tables: {
            users: proc { include :id, :username },
          },
          conventions:
            proc do
              column :id do
                rename_to :original_id
                type :integer
                required
              end
            end,
        )

      stub_database(
        connection,
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: true,
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

      result = described_class.new(schema).resolve
      table = result.tables.first
      id_col = table.columns.find { |c| c.name == "original_id" }

      expect(id_col).not_to be_nil
      expect(id_col.datatype).to eq(:integer)
      expect(id_col.nullable).to eq(false)
    end

    it "resolves added columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                add_column :existing_id, :numeric
              end,
          },
        )

      stub_database(
        connection,
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      added = table.columns.find { |c| c.name == "existing_id" }

      expect(added).not_to be_nil
      expect(added.datatype).to eq(:numeric)
      expect(added.nullable).to eq(true)
    end

    it "resolves indexes with convention-renamed columns" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id
                index :id, name: :idx_users_id
              end,
          },
          conventions:
            proc do
              column :id do
                rename_to :original_id
              end
            end,
        )

      stub_database(
        connection,
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      idx = table.indexes.first

      expect(idx.name).to eq("idx_users_id")
      expect(idx.column_names).to eq(["original_id"])
    end

    it "resolves constraints" do
      schema =
        build_schema(
          tables: {
            users:
              proc do
                include :id, :email
                check :email_format, "email LIKE '%@%'"
              end,
          },
        )

      stub_database(
        connection,
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
            email: {
              type: :text,
              null: false,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first

      expect(table.constraints.size).to eq(1)
      expect(table.constraints.first.name).to eq("email_format")
      expect(table.constraints.first.condition).to eq("email LIKE '%@%'")
    end

    it "resolves enums" do
      schema =
        build_schema(
          enums: {
            visibility:
              proc do
                value :public, 0
                value :private, 1
              end,
          },
        )

      stub_database(connection, table_columns: {}, primary_keys: {})

      result = described_class.new(schema).resolve

      expect(result.enums.size).to eq(1)
      enum = result.enums.first
      expect(enum.name).to eq("visibility")
      expect(enum.values).to eq({ "public" => 0, "private" => 1 })
      expect(enum.datatype).to eq(:integer)
    end

    it "resolves copy_structure_from by introspecting source table" do
      schema =
        build_schema(
          tables: {
            user_archive:
              proc do
                copy_structure_from :users
                include :id, :username
              end,
          },
        )

      stub_database(
        connection,
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

      result = described_class.new(schema).resolve
      table = result.tables.first

      expect(table.name).to eq("user_archive")
      expect(table.columns.map(&:name)).to contain_exactly("id", "username")
    end

    it "normalizes datatypes" do
      schema = build_schema(tables: { data: proc { include :binary_col, :string_col, :jsonb_col } })

      stub_database(
        connection,
        table_columns: {
          data: {
            binary_col: {
              type: :binary,
              null: true,
            },
            string_col: {
              type: :string,
              null: true,
            },
            jsonb_col: {
              type: :jsonb,
              null: true,
            },
          },
        },
        primary_keys: {
          data: [],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      types = table.columns.map { |c| [c.name, c.datatype] }.to_h

      expect(types["binary_col"]).to eq(:blob)
      expect(types["string_col"]).to eq(:text)
      expect(types["jsonb_col"]).to eq(:json)
    end

    it "applies per-table rename_to override" do
      schema =
        build_schema(
          tables: {
            posts:
              proc do
                include :id, :user_id
                column :user_id, rename_to: :author_id
              end,
          },
        )

      stub_database(
        connection,
        table_columns: {
          posts: {
            id: {
              type: :integer,
              null: false,
            },
            user_id: {
              type: :integer,
              null: false,
            },
          },
        },
        primary_keys: {
          posts: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      col = table.columns.find { |c| c.name == "author_id" }

      expect(col).not_to be_nil
      expect(table.columns.none? { |c| c.name == "user_id" }).to eq(true)
    end

    it "per-table rename_to takes precedence over conventions" do
      schema =
        build_schema(
          tables: {
            posts:
              proc do
                include :id
                column :id, rename_to: :post_original_id
              end,
          },
          conventions:
            proc do
              column :id do
                rename_to :original_id
              end
            end,
        )

      stub_database(
        connection,
        table_columns: {
          posts: {
            id: {
              type: :integer,
              null: false,
            },
          },
        },
        primary_keys: {
          posts: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      col = table.columns.find { |c| c.name == "post_original_id" }

      expect(col).not_to be_nil
      expect(table.columns.none? { |c| c.name == "original_id" }).to eq(true)
    end

    it "resolves a table with synthetic! using only add_columns" do
      schema =
        build_schema(
          tables: {
            log_entries:
              proc do
                synthetic!
                add_column :created_at, :datetime, required: true
                add_column :type, :text, required: true
                add_column :message, :text, required: true
                add_column :exception, :text
                add_column :details, :json
              end,
          },
        )

      stub_database(connection, table_columns: {}, primary_keys: {})

      result = described_class.new(schema).resolve
      table = result.tables.first

      expect(table.name).to eq("log_entries")
      expect(table.columns.size).to eq(5)
      expect(table.primary_key_column_names).to eq([])

      created_at = table.columns.find { |c| c.name == "created_at" }
      expect(created_at.datatype).to eq(:datetime)
      expect(created_at.nullable).to eq(false)

      details = table.columns.find { |c| c.name == "details" }
      expect(details.datatype).to eq(:json)
      expect(details.nullable).to eq(true)
    end

    it "resolves composite primary keys for nil source tables" do
      schema =
        build_schema(
          tables: {
            user_suspensions:
              proc do
                synthetic!
                primary_key :user_id, :suspended_at
                add_column :user_id, :numeric, required: true
                add_column :suspended_at, :datetime, required: true
                add_column :reason, :text
              end,
          },
        )

      stub_database(connection, table_columns: {}, primary_keys: {})

      result = described_class.new(schema).resolve
      table = result.tables.first

      expect(table.primary_key_column_names).to eq(%w[user_id suspended_at])
      expect(table.columns.find { |c| c.name == "user_id" }.is_primary_key).to eq(true)
      expect(table.columns.find { |c| c.name == "suspended_at" }.is_primary_key).to eq(true)
      expect(table.columns.find { |c| c.name == "reason" }.is_primary_key).to eq(false)
    end

    it "excludes globally ignored columns when no include list specified" do
      schema =
        build_schema(
          tables: {
            users: proc { include_all },
          },
          conventions: proc { ignore_columns :secret_token },
        )

      stub_database(
        connection,
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
            secret_token: {
              type: :text,
              null: true,
            },
          },
        },
        primary_keys: {
          users: ["id"],
        },
      )

      result = described_class.new(schema).resolve
      table = result.tables.first
      expect(table.columns.map(&:name)).to eq(["id"])
    end
  end
end
