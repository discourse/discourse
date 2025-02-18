# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::OutputConfigValidator do
  subject(:validator) { described_class.new(config, errors) }

  let(:errors) { [] }
  let(:config) { { output: output_config } }
  let(:output_config) do
    {
      schema_file: "db/intermediate_db_schema/100-base-schema.sql",
      models_directory: "lib/database/intermediate_db",
      models_namespace: "Migrations::Database::IntermediateDB",
    }
  end

  describe "#validate" do
    it "does not add any errors when config is correct" do
      validator.validate
      expect(errors).to be_empty
    end

    it "adds an error when schema file directory does not exist" do
      output_config[:schema_file] = "foo/bar/100-base-schema.sql"

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.output.schema_file_directory_not_found"),
      )
    end

    it "adds an error when models directory does not exist" do
      output_config[:models_directory] = "foo/bar"

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.output.models_directory_not_found"),
      )
    end

    it "adds an error when `models_namespace` does not exist" do
      output_config[:models_namespace] = "Foo::Bar::IntermediateDB"

      validator.validate
      expect(errors).to include(I18n.t("schema.validator.output.models_namespace_undefined"))
    end
  end
end
