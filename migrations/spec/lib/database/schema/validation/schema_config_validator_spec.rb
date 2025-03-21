# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::SchemaConfigValidator do
  subject(:validator) { described_class.new(schema_config, errors) }

  let(:errors) { [] }
  let(:schema_config) { { schema: { tables: {}, global: {} } } }

  describe "#validate" do
    it "calls all validators" do
      [
        ::Migrations::Database::Schema::Validation::GloballyExcludedTablesValidator,
        ::Migrations::Database::Schema::Validation::GloballyConfiguredColumnsValidator,
        ::Migrations::Database::Schema::Validation::TablesValidator,
      ].each { |klass| expect_any_instance_of(klass).to receive(:validate) }

      validator.validate
    end
  end
end
