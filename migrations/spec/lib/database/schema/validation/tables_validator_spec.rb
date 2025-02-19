# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::TablesValidator do
  subject(:validator) { described_class.new(config, errors, db) }

  let(:errors) { [] }
  let(:config) { { schema: schema_config } }
  let(:schema_config) do
    {
      tables: {
        users: {
        },
        posts: {
        },
      },
      global: {
        tables: {
          exclude: %w[schema_migrations user_auth_tokens],
        },
      },
    }
  end
  let(:db) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:columns_validator) do
    instance_double(::Migrations::Database::Schema::Validation::ColumnsValidator)
  end

  before do
    allow(db).to receive(:tables).and_return(
      %w[users topics posts schema_migrations user_auth_tokens],
    )

    allow(::Migrations::Database::Schema::Validation::ColumnsValidator).to receive(:new).with(
      config,
      errors,
      db,
    ).and_return(columns_validator)
    allow(columns_validator).to receive(:validate)
  end

  describe "#validate" do
    it "adds an error if a table is both configured and excluded" do
      schema_config[:tables].merge!(topics: {}, schema_migrations: {}, user_auth_tokens: {})

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t(
          "schema.validator.tables.excluded_tables_configured",
          table_names: "schema_migrations, user_auth_tokens",
        ),
      )
    end

    it "adds an error if an existing table is not configured and not excluded" do
      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.tables.not_configured", table_names: "topics"),
      )
    end

    it "validates the columns of all configured tables" do
      validator.validate

      expect(columns_validator).to have_received(:validate).exactly(2).times
      expect(columns_validator).to have_received(:validate).with("users")
      expect(columns_validator).to have_received(:validate).with("posts")
    end

    it "does not add errors if all existing tables are configured or excluded" do
      schema_config[:tables][:topics] = {}

      validator.validate
      expect(errors).to be_empty
    end
  end
end
