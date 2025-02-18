# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::SchemaConfigValidator do
  subject(:validator) { described_class.new(schema_config, errors) }

  let(:errors) { [] }
  let(:schema_config) { {} }

  describe "#validate" do
    it "calls all validators" do
      expect_any_instance_of(
        ::Migrations::Database::Schema::Validation::GloballyExcludedTablesValidator,
      ).to receive(:validate)
      expect_any_instance_of(
        ::Migrations::Database::Schema::Validation::GloballyConfiguredColumnsValidator,
      ).to receive(:validate)
      expect_any_instance_of(
        ::Migrations::Database::Schema::Validation::TablesValidator,
      ).to receive(:validate)
      expect_any_instance_of(
        ::Migrations::Database::Schema::Validation::ColumnsValidator,
      ).to receive(:validate)

      validator.validate
    end
  end
end
