# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Generator do
  after { Migrations::Database::Schema.reset! }

  let(:resolved_definition) do
    table =
      Migrations::Database::Schema::TableDefinition.new(
        name: "users",
        columns: [
          Migrations::Database::Schema::ColumnDefinition.new(
            name: "id",
            datatype: :integer,
            nullable: false,
            max_length: nil,
            is_primary_key: true,
            enum: nil,
          ),
          Migrations::Database::Schema::ColumnDefinition.new(
            name: "username",
            datatype: :text,
            nullable: false,
            max_length: nil,
            is_primary_key: false,
            enum: nil,
          ),
        ],
        indexes: [],
        primary_key_column_names: ["id"],
        constraints: [],
      )

    enum =
      Migrations::Database::Schema::EnumDefinition.new(
        name: "visibility",
        values: {
          "public" => 0,
          "private" => 1,
        },
        datatype: :integer,
      )

    Migrations::Database::Schema::Definition.new(tables: [table], enums: [enum])
  end

  describe "#generate" do
    it "generates SQL, model, and enum files" do
      Dir.mktmpdir do |tmpdir|
        sql_path = File.join(tmpdir, "schema.sql")
        models_path = File.join(tmpdir, "models")
        enums_path = File.join(tmpdir, "enums")

        Migrations::Database::Schema.configure do
          output do
            schema_file sql_path
            models_directory models_path
            models_namespace "Test::Models"
            enums_directory enums_path
            enums_namespace "Test::Enums"
          end
        end

        validation_result =
          Migrations::Database::Schema::DSL::ValidationResult.new(errors: [], warnings: [])
        validator = instance_double(Migrations::Database::Schema::DSL::Validator)
        allow(validator).to receive(:validate).and_return(validation_result)
        allow(Migrations::Database::Schema::DSL::Validator).to receive(:new).and_return(validator)

        resolver = instance_double(Migrations::Database::Schema::DSL::SchemaResolver)
        allow(resolver).to receive(:resolve).and_return(resolved_definition)
        allow(Migrations::Database::Schema::DSL::SchemaResolver).to receive(:new).and_return(
          resolver,
        )

        allow(Migrations::Database::Schema).to receive(:format_ruby_files)

        generator = described_class.new(Migrations::Database::Schema)
        result = generator.generate

        expect(result).to eq(resolved_definition)
        expect(File.exist?(sql_path)).to be true
        expect(Dir.exist?(models_path)).to be true
        expect(Dir.exist?(enums_path)).to be true

        sql_content = File.read(sql_path)
        expect(sql_content).to include("CREATE TABLE users")
        expect(sql_content).to include("id")
        expect(sql_content).to include("username")

        model_files = Dir[File.join(models_path, "*.rb")]
        expect(model_files.size).to eq(1)
        expect(File.basename(model_files.first)).to eq("user.rb")

        enum_files = Dir[File.join(enums_path, "*.rb")]
        expect(enum_files.size).to eq(1)
        expect(File.basename(enum_files.first)).to eq("visibility.rb")
      end
    end
  end
end
