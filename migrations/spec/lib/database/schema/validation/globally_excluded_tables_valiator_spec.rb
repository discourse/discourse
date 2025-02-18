# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::GloballyExcludedTablesValidator do
  subject(:validator) { described_class.new(config, errors, db) }

  let(:errors) { [] }
  let(:config) { { schema: schema_config } }
  let(:schema_config) { { global: { tables: { exclude: excluded_tables } } } }
  let(:excluded_tables) { %w[schema_migrations user_auth_tokens] }
  let(:db) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  before do
    allow(db).to receive(:tables).and_return(
      %w[users posts topics user_auth_tokens schema_migrations],
    )
  end

  describe "#validate" do
    it "adds an error for non-existing excluded tables" do
      excluded_tables.push("foo", "bar")

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.global.excluded_tables_missing", table_names: "bar, foo"),
      )
    end

    it "doesn't add errors when all excluded tables exist" do
      validator.validate
      expect(errors).to be_empty
    end
  end
end
