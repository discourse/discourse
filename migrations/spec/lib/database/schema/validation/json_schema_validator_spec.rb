# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::JsonSchemaValidator do
  subject(:validator) { described_class.new(config, errors) }

  let(:errors) { [] }
  let(:config) do
    {
      output: {
        schema_file: "db/intermediate_db_schema/100-base-schema.sql",
        models_directory: "lib/database/intermediate_db",
        models_namespace: "Migrations::Database::IntermediateDB",
      },
      schema: {
        tables: {
        },
        global: {
          columns: {
          },
          tables: {
          },
        },
      },
      plugins: [],
    }
  end

  describe "#validate" do
    it "validates correct config without errors" do
      validator.validate
      expect(errors).to eq([])
    end

    it "detects missing required properties" do
      config.except!(:output, :plugins)

      validator.validate
      expect(errors).to contain_exactly(
        "object at root is missing required properties: output, plugins",
      )
    end

    it "detects nested, missing required properties" do
      config.except!(:plugins)
      config[:schema].except!(:global)

      validator.validate
      expect(errors).to contain_exactly(
        "object at `/schema` is missing required properties: global",
        "object at root is missing required properties: plugins",
      )
    end

    it "detects datatype mismatches" do
      config[:output][:models_namespace] = 123

      validator.validate
      expect(errors).to contain_exactly("value at `/output/models_namespace` is not a string")
    end

    it "detects that `include` and `exclude` of columns can't be used together" do
      config[:schema][:tables] = { users: { columns: { include: ["id"], exclude: ["name"] } } }

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t(
          "schema.validator.include_exclude_not_allowed",
          path: "`/schema/tables/users/columns`",
        ),
      )
    end
  end
end
