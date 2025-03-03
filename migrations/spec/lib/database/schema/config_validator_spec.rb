# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::ConfigValidator do
  subject(:validator) { described_class.new }

  let(:config) { {} }

  describe "#validate" do
    context "with no errors" do
      before do
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::JsonSchemaValidator,
        ).to receive(:validate)
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::OutputConfigValidator,
        ).to receive(:validate)
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::SchemaConfigValidator,
        ).to receive(:validate)
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::PluginConfigValidator,
        ).to receive(:validate)
      end

      it "validates the config with JSON schema" do
        expect_any_instance_of(
          Migrations::Database::Schema::Validation::JsonSchemaValidator,
        ).to receive(:validate)

        validator.validate(config)
        expect(validator.has_errors?).to be false
      end

      it "calls the output config validator" do
        expect_any_instance_of(
          Migrations::Database::Schema::Validation::OutputConfigValidator,
        ).to receive(:validate)

        validator.validate(config)
        expect(validator.has_errors?).to be false
      end

      it "calls the schema config validator" do
        expect_any_instance_of(
          Migrations::Database::Schema::Validation::SchemaConfigValidator,
        ).to receive(:validate)

        validator.validate(config)
        expect(validator.has_errors?).to be false
      end

      it "calls the plugin config validator" do
        expect_any_instance_of(
          Migrations::Database::Schema::Validation::PluginConfigValidator,
        ).to receive(:validate)

        validator.validate(config)
        expect(validator.has_errors?).to be false
      end
    end

    context "with errors" do
      before do
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::JsonSchemaValidator,
        ).to receive(:validate)
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::OutputConfigValidator,
        ).to receive(:validate) do |instance|
          instance.instance_variable_get(:@errors) << "Output config error"
        end
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::SchemaConfigValidator,
        ).to receive(:validate) do |instance|
          instance.instance_variable_get(:@errors) << "Schema config error"
        end
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::PluginConfigValidator,
        ).to receive(:validate) do |instance|
          instance.instance_variable_get(:@errors) << "Plugin config error"
        end
      end

      it "returns only the errors from the schema validator if the config doesn't match the schema" do
        allow_any_instance_of(
          Migrations::Database::Schema::Validation::JsonSchemaValidator,
        ).to receive(:validate) do |instance|
          instance.instance_variable_get(:@errors) << "JSON schema error"
        end

        validator.validate(config)
        expect(validator.errors).to contain_exactly("JSON schema error")
        expect(validator.has_errors?).to be true
      end

      it "collects errors from all validators" do
        validator.validate(config)

        expect(validator.errors).to contain_exactly(
          "Output config error",
          "Schema config error",
          "Plugin config error",
        )
        expect(validator.has_errors?).to be true
      end
    end
  end
end
