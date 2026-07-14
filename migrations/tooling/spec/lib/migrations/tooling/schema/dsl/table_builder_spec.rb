# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::TableBuilder do
  after { Migrations::Tooling::Schema.reset! }

  describe "Schema.table" do
    it "registers a basic table" do
      Migrations::Tooling::Schema.table :users do
        primary_key :id
        include :id, :username, :email
      end

      table = Migrations::Tooling::Schema.tables["users"]
      expect(table.name).to eq("users")
      expect(table.source_table_name).to eq("users")
      expect(table.primary_key_columns).to eq(%w[id])
      expect(table.included_column_names).to eq(%w[id username email])
    end

    it "raises when block has no include, include_all, ignore, or synthetic!" do
      expect do
        Migrations::Tooling::Schema.table :badge_groupings do
          primary_key :id
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /must use `include_all`, `include`, or `ignore`/,
      )
    end

    it "raises on invalid model mode" do
      expect do
        Migrations::Tooling::Schema.table :users do
          model :invalid
        end
      end.to raise_error(Migrations::Tooling::Schema::ConfigError, /Invalid model mode :invalid/)
    end

    it "defaults the conflict strategy to `:raise`" do
      Migrations::Tooling::Schema.table :users do
        primary_key :id
        include :id
      end

      expect(Migrations::Tooling::Schema.tables["users"].conflict_strategy).to eq(:raise)
    end

    it "records a declared conflict strategy" do
      Migrations::Tooling::Schema.table :uploads do
        conflict_strategy :ignore
        synthetic!
        primary_key :id
        add_column :id, :text
      end

      expect(Migrations::Tooling::Schema.tables["uploads"].conflict_strategy).to eq(:ignore)
    end

    it "raises on an invalid conflict strategy" do
      expect do
        Migrations::Tooling::Schema.table :users do
          conflict_strategy :maybe
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /Invalid conflict strategy :maybe/,
      )
    end

    it "raises when synthetic table uses include or include_all" do
      %i[include include_all].each do |method|
        expect do
          Migrations::Tooling::Schema.table :"log_#{method}" do
            synthetic!
            send(method, *(:id if method == :include))
          end
        end.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /synthetic and cannot use `include` or `include_all`/,
        )
      end
    end

    it "raises when columns are both included and ignored" do
      expect do
        Migrations::Tooling::Schema.table :users do
          include :id, :email
          ignore :email, reason: "duplicate"
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /both included and ignored.*email/,
      )
    end

    it "raises when both include and include_all are used" do
      expect do
        Migrations::Tooling::Schema.table :users do
          include :id
          include_all
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /both `include` and `include_all`/,
      )
    end

    it "raises on duplicate table name" do
      Migrations::Tooling::Schema.table(:users) { include_all }

      expect do Migrations::Tooling::Schema.table(:users) { include_all } end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /already registered/,
      )
    end
  end
end
