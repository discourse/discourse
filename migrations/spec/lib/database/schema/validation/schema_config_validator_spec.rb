# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::SchemaConfigValidator do
  subject(:validator) { described_class.new(schema_config, errors) }

  let(:errors) { [] }
  let(:schema_config) { {} }

  describe "#validate" do
    it "calls all validators" do
      [
        ::Migrations::Database::Schema::Validation::GloballyExcludedTablesValidator,
        ::Migrations::Database::Schema::Validation::GloballyConfiguredColumnsValidator,
        ::Migrations::Database::Schema::Validation::TablesValidator,
        ::Migrations::Database::Schema::Validation::ColumnsValidator,
      ].each { |klass| expect_any_instance_of(klass).to receive(:validate) }

      validator.validate
    end
  end
end
