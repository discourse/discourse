# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::ConfigBuilder do
  after { Migrations::Tooling::Schema.reset! }

  describe "Schema.configure" do
    it "registers output configuration" do
      Migrations::Tooling::Schema.configure do
        output do
          schema_file "db/schema.sql"
          models_directory "lib/models"
          models_namespace "Test::Models"
          enums_directory "lib/enums"
          enums_namespace "Test::Enums"
        end
      end

      config = Migrations::Tooling::Schema.config
      expect(config).to be_a(Migrations::Tooling::Schema::DSL::Configuration)

      output = config.output_config
      expect(output.schema_file).to eq("db/schema.sql")
      expect(output.models_directory).to eq("lib/models")
      expect(output.models_namespace).to eq("Test::Models")
      expect(output.enums_directory).to eq("lib/enums")
      expect(output.enums_namespace).to eq("Test::Enums")
    end

    it "raises when output block is missing" do
      expect do Migrations::Tooling::Schema.configure {} end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /output/,
      )
    end

    it "raises when schema_file is missing" do
      expect do Migrations::Tooling::Schema.configure { output {} } end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /schema_file/,
      )
    end

    it "raises when other output fields are missing" do
      expect do
        Migrations::Tooling::Schema.configure { output { schema_file "db/schema.sql" } }
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /models_directory.*models_namespace.*enums_directory.*enums_namespace/,
      )
    end

    it "raises on duplicate configure calls" do
      Migrations::Tooling::Schema.configure do
        output do
          schema_file "db/schema.sql"
          models_directory "lib/models"
          models_namespace "Test::Models"
          enums_directory "lib/enums"
          enums_namespace "Test::Enums"
        end
      end

      expect do
        Migrations::Tooling::Schema.configure do
          output do
            schema_file "db/other.sql"
            models_directory "lib/models"
            models_namespace "Test::Models"
            enums_directory "lib/enums"
            enums_namespace "Test::Enums"
          end
        end
      end.to raise_error(Migrations::Tooling::Schema::ConfigError, /already registered/)
    end
  end
end
