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

  describe "building a table definition" do
    def builder(name = :users)
      described_class.new(name)
    end

    describe "#initialize" do
      it "stringifies the name and uses it as the default source table name" do
        table = builder(:users).tap(&:include_all).build
        expect(table.name).to eq("users")
        expect(table.source_table_name).to eq("users")
      end

      it "defaults the optional configuration to empty/nil values" do
        table = builder.tap(&:include_all).build
        expect(table.primary_key_columns).to be_nil
        expect(table.forced_column_names).to be_nil
        expect(table.column_options).to eq({})
        expect(table.added_columns).to eq([])
        expect(table.indexes).to eq([])
        expect(table.constraints).to eq([])
        expect(table.ignored_columns_map).to eq({})
        expect(table.ignore_plugin_columns).to eq(false)
        expect(table.ignore_plugin_names).to be_nil
        expect(table.model_mode).to be_nil
      end
    end

    describe "#copy_structure_from" do
      it "overrides the source table name" do
        b = builder(:new_users)
        b.copy_structure_from(:users)
        b.include_all
        expect(b.build.source_table_name).to eq("users")
      end
    end

    describe "#synthetic!" do
      it "clears the source table name" do
        b = builder
        b.synthetic!
        expect(b.build.source_table_name).to be_nil
      end
    end

    describe "#primary_key" do
      it "stores stringified, flattened column names" do
        b = builder
        b.primary_key(:topic_id, [:post_id])
        b.include_all
        expect(b.build.primary_key_columns).to eq(%w[topic_id post_id])
      end
    end

    describe "#include" do
      it "accumulates stringified column names across calls" do
        b = builder
        b.include(:id, [:username])
        b.include(:email)
        expect(b.build.included_column_names).to eq(%w[id username email])
      end
    end

    describe "#include!" do
      it "stores forced columns, stringified and flattened" do
        b = builder
        b.include!(:created_at, [:updated_at])
        b.include_all
        expect(b.build.forced_column_names).to eq(%w[created_at updated_at])
      end

      it "leaves forced columns nil when none are forced" do
        expect(builder.tap(&:include_all).build.forced_column_names).to be_nil
      end
    end

    describe "#column" do
      it "stores column options keyed by stringified name" do
        b = builder
        b.column(:title, :string, required: true, max_length: 100, rename_to: :name)
        b.include_all
        opts = b.build.column_options.fetch("title")
        expect(opts.type).to eq("string")
        expect(opts.required).to eq(true)
        expect(opts.max_length).to eq(100)
        expect(opts.rename_to).to eq("name")
      end

      it "stores required: false from an option without a block" do
        b = builder
        b.column(:title, :text, required: false)
        b.include_all
        expect(b.build.column_options.fetch("title").required).to eq(false)
      end

      it "falls back to the :type option when no positional type is given" do
        b = builder
        b.column(:title, type: :text)
        b.include_all
        expect(b.build.column_options.fetch("title").type).to eq("text")
      end

      it "leaves the type nil when neither positional nor option type is given" do
        b = builder
        b.column(:title)
        b.include_all
        expect(b.build.column_options.fetch("title").type).to be_nil
      end

      it "leaves rename_to nil when not provided" do
        b = builder
        b.column(:title, :text)
        b.include_all
        expect(b.build.column_options.fetch("title").rename_to).to be_nil
      end

      it "uses a block-based ColumnOptionsBuilder when a block is given" do
        b = builder
        b.column(:title) do
          type :string
          required
          max_length 50
          rename_to :name
        end
        b.include_all
        opts = b.build.column_options.fetch("title")
        expect(opts.type).to eq("string")
        expect(opts.required).to eq(true)
        expect(opts.max_length).to eq(50)
        expect(opts.rename_to).to eq("name")
      end
    end

    describe "#add_column" do
      it "appends a synthetic column with stringified name and type" do
        b = builder
        b.add_column(:slug, :string)
        b.include_all
        col = b.build.added_columns.fetch(0)
        expect(col.name).to eq("slug")
        expect(col.type).to eq("string")
        expect(col.required).to eq(false)
        expect(col.enum).to be_nil
      end

      it "stores the required flag and a stringified enum name" do
        b = builder
        b.add_column(:status, :integer, required: true, enum: :post_status)
        b.include_all
        col = b.build.added_columns.fetch(0)
        expect(col.required).to eq(true)
        expect(col.enum).to eq("post_status")
      end

      it "keeps enum nil when not provided" do
        b = builder
        b.add_column(:slug, :string)
        b.include_all
        expect(b.build.added_columns.fetch(0).enum).to be_nil
      end
    end

    describe "#ignore" do
      it "maps each stringified column to its reason" do
        b = builder
        b.ignore(:legacy, [:deprecated], reason: "gone")
        expect(b.build.ignored_columns_map).to eq("legacy" => "gone", "deprecated" => "gone")
      end

      it "uses a nil reason by default" do
        b = builder
        b.ignore(:legacy)
        expect(b.build.ignored_columns_map).to eq("legacy" => nil)
      end
    end

    describe "#index" do
      it "stores a non-unique index with a generated name by default" do
        b = builder
        b.index(:user_id, [:topic_id])
        b.include_all
        idx = b.build.indexes.fetch(0)
        expect(idx.column_names).to eq(%w[user_id topic_id])
        expect(idx.name).to eq("idx_users_user_id_topic_id")
        expect(idx.unique).to eq(false)
        expect(idx.condition).to be_nil
      end

      it "uses an explicit name and where condition when given" do
        b = builder
        b.index(:user_id, name: :my_index, where: "deleted_at IS NULL")
        b.include_all
        idx = b.build.indexes.fetch(0)
        expect(idx.name).to eq("my_index")
        expect(idx.condition).to eq("deleted_at IS NULL")
      end

      it "honours the unique flag and reflects it in the generated name" do
        b = builder
        b.index(:user_id, unique: true)
        b.include_all
        idx = b.build.indexes.fetch(0)
        expect(idx.unique).to eq(true)
        expect(idx.name).to eq("idx_unique_users_user_id")
      end
    end

    describe "#unique_index" do
      it "creates a unique index with a generated name" do
        b = builder
        b.unique_index(:email)
        b.include_all
        idx = b.build.indexes.fetch(0)
        expect(idx.unique).to eq(true)
        expect(idx.name).to eq("idx_unique_users_email")
        expect(idx.column_names).to eq(%w[email])
        expect(idx.condition).to be_nil
      end

      it "passes through an explicit name and where condition" do
        b = builder
        b.unique_index(:email, name: :uniq_email, where: "verified")
        b.include_all
        idx = b.build.indexes.fetch(0)
        expect(idx.name).to eq("uniq_email")
        expect(idx.condition).to eq("verified")
      end
    end

    describe "#check" do
      it "appends a check constraint with stringified name and condition" do
        b = builder
        b.check(:positive_score, "score > 0")
        b.include_all
        constraint = b.build.constraints.fetch(0)
        expect(constraint.name).to eq("positive_score")
        expect(constraint.type).to eq(:check)
        expect(constraint.condition).to eq("score > 0")
      end
    end

    describe "#ignore_plugin_columns!" do
      it "enables ignoring plugin columns and leaves the names nil when none given" do
        b = builder
        b.ignore_plugin_columns!
        b.include_all
        table = b.build
        expect(table.ignore_plugin_columns).to eq(true)
        expect(table.ignore_plugin_names).to be_nil
      end

      it "normalizes given plugin names (underscores to hyphens)" do
        b = builder
        b.ignore_plugin_columns!(:discourse_ai, ["discourse_solved"])
        b.include_all
        table = b.build
        expect(table.ignore_plugin_columns).to eq(true)
        expect(table.ignore_plugin_names).to eq(%w[discourse-ai discourse-solved])
      end
    end

    describe "#model" do
      it "stores a valid model mode as a symbol" do
        b = builder
        b.model("extended")
        b.include_all
        expect(b.build.model_mode).to eq(:extended)
      end

      it "accepts the :manual mode" do
        b = builder
        b.model(:manual)
        b.include_all
        expect(b.build.model_mode).to eq(:manual)
      end

      it "raises a ConfigError for an unknown mode, naming the table" do
        expect { builder(:posts).model(:bogus) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Invalid model mode :bogus for table :posts.*Valid: extended, manual/,
        )
      end
    end

    describe "#build" do
      it "freezes the returned collections" do
        b = builder
        b.include_all
        b.add_column(:slug, :string)
        b.index(:slug)
        b.check(:c, "true")
        table = b.build
        expect(table.column_options).to be_frozen
        expect(table.added_columns).to be_frozen
        expect(table.indexes).to be_frozen
        expect(table.constraints).to be_frozen
        expect(table.ignored_columns_map).to be_frozen
      end

      it "allows a source table with only ignored columns" do
        b = builder
        b.ignore(:legacy)
        expect { b.build }.not_to raise_error
      end

      it "raises naming the table when no inclusion strategy is given" do
        expect { builder(:posts).build }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Table :posts must use `include_all`, `include`, or `ignore`/,
        )
      end

      it "raises naming the table when a synthetic table uses include" do
        b = builder(:posts)
        b.synthetic!
        b.include(:id)
        expect { b.build }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Table :posts is synthetic/,
        )
      end

      it "raises naming the table when both include and include_all are used" do
        b = builder(:posts)
        b.include(:id)
        b.include_all
        expect { b.build }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Table :posts cannot use both `include` and `include_all`/,
        )
      end

      it "raises when included and ignored columns overlap on multiple names" do
        b = builder(:posts)
        b.include(:id, :email, :name)
        b.ignore(:email, :name)
        expect { b.build }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Table :posts has columns that are both included and ignored: email, name/,
        )
      end

      it "does not raise when included and ignored columns do not overlap" do
        b = builder
        b.include(:id)
        b.ignore(:legacy)
        expect { b.build }.not_to raise_error
      end
    end

    describe Migrations::Tooling::Schema::DSL::ColumnOptionsBuilder do
      it "builds options from each setter" do
        opts =
          described_class
            .new
            .tap do |b|
              b.type(:string)
              b.max_length(20)
              b.rename_to(:renamed)
              b.required(false)
            end
            .build
        expect(opts.type).to eq("string")
        expect(opts.max_length).to eq(20)
        expect(opts.rename_to).to eq("renamed")
        expect(opts.required).to eq(false)
      end

      it "defaults required to true when called without an argument" do
        opts = described_class.new.tap(&:required).build
        expect(opts.required).to eq(true)
      end

      it "defaults all options to nil when no setters are called" do
        opts = described_class.new.build
        expect(opts.type).to be_nil
        expect(opts.required).to be_nil
        expect(opts.max_length).to be_nil
        expect(opts.rename_to).to be_nil
      end
    end
  end
end
