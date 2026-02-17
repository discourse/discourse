# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::TableBuilder do
  after { Migrations::Database::Schema.reset! }

  describe "Schema.table" do
    it "registers a basic table" do
      Migrations::Database::Schema.table :users do
        primary_key :id
        include :id, :username, :email
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.name).to eq(:users)
      expect(table.source_table_name).to eq(:users)
      expect(table.primary_key_columns).to eq(%i[id])
      expect(table.included_column_names).to eq(%i[id username email])
    end

    it "registers a table without a block (include_all implied)" do
      Migrations::Database::Schema.table :badge_groupings

      table = Migrations::Database::Schema.tables[:badge_groupings]
      expect(table.name).to eq(:badge_groupings)
      expect(table.included_column_names).to be_nil
    end

    it "supports include_all to explicitly include all columns" do
      Migrations::Database::Schema.table :badge_groupings do
        include_all
      end

      table = Migrations::Database::Schema.tables[:badge_groupings]
      expect(table.name).to eq(:badge_groupings)
      expect(table.included_column_names).to be_nil
    end

    it "raises when block has no include, include_all, ignore, or synthetic!" do
      expect do
        Migrations::Database::Schema.table :badge_groupings do
          primary_key :id
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /must use `include_all`, `include`, or `ignore`/,
      )
    end

    it "supports copy_structure_from" do
      Migrations::Database::Schema.table :user_archive do
        include_all
        copy_structure_from :users
      end

      table = Migrations::Database::Schema.tables[:user_archive]
      expect(table.source_table_name).to eq(:users)
    end

    it "supports synthetic! for tables without a PG source" do
      Migrations::Database::Schema.table :log_entries do
        synthetic!
        add_column :message, :text, required: true
      end

      table = Migrations::Database::Schema.tables[:log_entries]
      expect(table.source_table_name).to be_nil
    end

    it "supports column options via keyword arguments" do
      Migrations::Database::Schema.table :users do
        include_all
        column :email, :text, required: true, max_length: 255
      end

      table = Migrations::Database::Schema.tables[:users]
      opts = table.column_options_for(:email)
      expect(opts.type).to eq(:text)
      expect(opts.required).to eq(true)
      expect(opts.max_length).to eq(255)
    end

    it "supports column options via block" do
      Migrations::Database::Schema.table :users do
        include_all
        column :email do
          type :text
          required
          max_length 255
        end
      end

      table = Migrations::Database::Schema.tables[:users]
      opts = table.column_options_for(:email)
      expect(opts.type).to eq(:text)
      expect(opts.required).to eq(true)
      expect(opts.max_length).to eq(255)
    end

    it "supports rename_to via keyword arguments" do
      Migrations::Database::Schema.table :posts do
        include_all
        column :user_id, rename_to: :author_id
      end

      table = Migrations::Database::Schema.tables[:posts]
      opts = table.column_options_for(:user_id)
      expect(opts.rename_to).to eq(:author_id)
    end

    it "supports rename_to via block" do
      Migrations::Database::Schema.table :posts do
        include_all
        column :user_id do
          rename_to :author_id
          type :numeric
        end
      end

      table = Migrations::Database::Schema.tables[:posts]
      opts = table.column_options_for(:user_id)
      expect(opts.rename_to).to eq(:author_id)
      expect(opts.type).to eq(:numeric)
    end

    it "supports required: false to force nullable" do
      Migrations::Database::Schema.table :users do
        include_all
        column :created_at, required: false
      end

      table = Migrations::Database::Schema.tables[:users]
      opts = table.column_options_for(:created_at)
      expect(opts.required).to eq(false)
    end

    it "supports adding synthetic columns" do
      Migrations::Database::Schema.table :users do
        include_all
        add_column :existing_id, :numeric
        add_column :status, :integer, required: true
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.added_columns.size).to eq(2)
      expect(table.added_columns[0].name).to eq(:existing_id)
      expect(table.added_columns[0].type).to eq(:numeric)
      expect(table.added_columns[0].required).to eq(false)
      expect(table.added_columns[1].required).to eq(true)
    end

    it "normalizes enum names on added columns" do
      Migrations::Database::Schema.table :uploads do
        synthetic!
        add_column :type, :text, enum: "upload_type"
      end

      table = Migrations::Database::Schema.tables[:uploads]
      expect(table.added_columns.first.enum).to eq(:upload_type)
    end

    it "supports ignoring columns with reasons" do
      Migrations::Database::Schema.table :users do
        ignore :admin_notes, reason: "Not needed for migration"
        ignore :legacy_flag, reason: "Deprecated column"
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.ignored_column_names).to eq(%i[admin_notes legacy_flag])
      expect(table.ignore_reason_for(:admin_notes)).to eq("Not needed for migration")
    end

    it "allows batch ignoring columns" do
      Migrations::Database::Schema.table :users do
        ignore :admin_notes, :legacy_flag, :old_col
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.ignored_column_names).to eq(%i[admin_notes legacy_flag old_col])
    end

    it "allows batch ignoring with a shared reason" do
      Migrations::Database::Schema.table :users do
        ignore :admin_notes, :legacy_flag, reason: "Deprecated"
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.ignored_column_names).to eq(%i[admin_notes legacy_flag])
      expect(table.ignore_reason_for(:admin_notes)).to eq("Deprecated")
      expect(table.ignore_reason_for(:legacy_flag)).to eq("Deprecated")
    end

    it "supports indexes" do
      Migrations::Database::Schema.table :users do
        include_all
        index :username, unique: true
        index %i[first_name last_name], name: :idx_full_name
        unique_index :email, where: "email IS NOT NULL"
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.indexes.size).to eq(3)
      expect(table.indexes[0].column_names).to eq(%i[username])
      expect(table.indexes[0].unique).to eq(true)
      expect(table.indexes[1].name).to eq(:idx_full_name)
      expect(table.indexes[2].unique).to eq(true)
      expect(table.indexes[2].condition).to eq("email IS NOT NULL")
    end

    it "supports check constraints" do
      Migrations::Database::Schema.table :users do
        include_all
        check :email_format, "email LIKE '%@%'"
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.constraints.size).to eq(1)
      expect(table.constraints[0].name).to eq(:email_format)
      expect(table.constraints[0].type).to eq(:check)
      expect(table.constraints[0].condition).to eq("email LIKE '%@%'")
    end

    it "supports plugin ownership" do
      Migrations::Database::Schema.table :poll_votes do
        include_all
        plugin "poll"
        ignore_plugin_columns!
      end

      table = Migrations::Database::Schema.tables[:poll_votes]
      expect(table.plugin_name).to eq("poll")
      expect(table.ignore_plugin_columns?).to eq(true)
    end

    it "defaults model_mode to nil" do
      Migrations::Database::Schema.table :users do
        include_all
        primary_key :id
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.model_mode).to be_nil
    end

    it "supports model :extended" do
      Migrations::Database::Schema.table :uploads do
        include_all
        model :extended
      end

      table = Migrations::Database::Schema.tables[:uploads]
      expect(table.model_mode).to eq(:extended)
    end

    it "supports model :manual" do
      Migrations::Database::Schema.table :log_entries do
        include_all
        model :manual
      end

      table = Migrations::Database::Schema.tables[:log_entries]
      expect(table.model_mode).to eq(:manual)
    end

    it "raises on invalid model mode" do
      expect do
        Migrations::Database::Schema.table :users do
          model :invalid
        end
      end.to raise_error(Migrations::Database::Schema::ConfigError, /Invalid model mode :invalid/)
    end

    it "supports include! to override global ignores" do
      Migrations::Database::Schema.table :users do
        include :id, :updated_at
        include! :updated_at
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.forced_column_names).to eq(%i[updated_at])
    end

    it "supports ignore_plugin_columns! with specific plugin names" do
      Migrations::Database::Schema.table :users do
        include_all
        ignore_plugin_columns! :polls, :discourse_ai
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.ignore_plugin_columns?).to eq(true)
      expect(table.ignore_plugin_names).to eq(%i[polls discourse_ai])
    end

    it "sets ignore_plugin_names to nil when no plugins specified" do
      Migrations::Database::Schema.table :users do
        include_all
        ignore_plugin_columns!
      end

      table = Migrations::Database::Schema.tables[:users]
      expect(table.ignore_plugin_columns?).to eq(true)
      expect(table.ignore_plugin_names).to be_nil
    end

    it "raises when synthetic table uses include" do
      expect do
        Migrations::Database::Schema.table :log_entries do
          synthetic!
          include :id
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /synthetic and cannot use `include` or `include_all`/,
      )
    end

    it "raises when synthetic table uses include_all" do
      expect do
        Migrations::Database::Schema.table :log_entries do
          synthetic!
          include_all
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /synthetic and cannot use `include` or `include_all`/,
      )
    end

    it "raises when columns are both included and ignored" do
      expect do
        Migrations::Database::Schema.table :users do
          include :id, :email
          ignore :email, reason: "duplicate"
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /both included and ignored.*email/,
      )
    end

    it "raises on duplicate table name" do
      Migrations::Database::Schema.table(:users) { include_all }

      expect do Migrations::Database::Schema.table(:users) { include_all } end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end
end
