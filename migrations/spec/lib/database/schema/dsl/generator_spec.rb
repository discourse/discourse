# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Generator do
  after { Migrations::Database::Schema.reset! }

  def make_table(name, model_mode: nil)
    Migrations::Database::Schema::TableDefinition.new(
      name:,
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
      model_mode:,
    )
  end

  let(:resolved_definition) do
    table = make_table("users")

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

  def stub_validation_and_resolution(definition)
    allow(Migrations::Database::Schema).to receive(:preflight).and_return(
      Migrations::Database::Schema::PreflightResult.new(resolved: definition, errors: []),
    )

    allow(Migrations::Database::Schema::Helpers).to receive(:format_ruby_files)
  end

  def configure_output(tmpdir)
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

    { sql: sql_path, models: models_path, enums: enums_path }
  end

  describe "#generate" do
    it "raises a generation error when preflight returns validation failures" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)

        allow(Migrations::Database::Schema).to receive(:preflight).and_return(
          Migrations::Database::Schema::PreflightResult.new(
            resolved: nil,
            errors: ["Table 'users': bad config"],
          ),
        )

        expect { described_class.new(Migrations::Database::Schema).generate }.to raise_error(
          Migrations::Database::Schema::GenerationError,
          /Schema validation failed with 1 error/,
        )
      end
    end

    it "generates SQL, model, and enum files" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        generator = described_class.new(Migrations::Database::Schema)
        result = generator.generate

        expect(result).to eq(resolved_definition)
        expect(File.exist?(paths[:sql])).to be true
        expect(Dir.exist?(paths[:models])).to be true
        expect(Dir.exist?(paths[:enums])).to be true

        sql_content = File.read(paths[:sql])
        expect(sql_content).to include("CREATE TABLE users")
        expect(sql_content).to include("id")
        expect(sql_content).to include("username")

        model_files = Dir[File.join(paths[:models], "*.rb")]
        expect(model_files.size).to eq(1)
        expect(File.basename(model_files.first)).to eq("user.rb")

        enum_files = Dir[File.join(paths[:enums], "*.rb")]
        expect(enum_files.size).to eq(1)
        expect(File.basename(enum_files.first)).to eq("visibility.rb")
      end
    end

    it "uses the configured namespace in model insert calls" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Database::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("::Test::Models.insert(")
        expect(model_content).not_to include("IntermediateDB.insert(")
      end
    end

    it "derives header label from models_namespace" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Database::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("auto-generated from the Models schema")
      end
    end

    it "does not write model file for :manual mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("log_entries", model_mode: :manual)
        definition = Migrations::Database::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Database::Schema).generate

        expect(Dir[File.join(paths[:models], "*.rb")]).to be_empty
      end
    end

    it "does not create a model file for :manual mode even when models directory exists" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("log_entries", model_mode: :manual)
        definition = Migrations::Database::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        FileUtils.mkdir_p(paths[:models])

        described_class.new(Migrations::Database::Schema).generate

        expect(File.exist?(File.join(paths[:models], "log_entry.rb"))).to be false
      end
    end

    it "generates model file with custom code markers for :extended mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("uploads", model_mode: :extended)
        definition = Migrations::Database::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Database::Schema).generate

        content = File.read(File.join(paths[:models], "upload.rb"))
        expect(content).to include("# -- custom code --")
        expect(content).to include("# -- end custom code --")
      end
    end

    it "preserves custom code between markers on regeneration for :extended mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("uploads", model_mode: :extended)
        definition = Migrations::Database::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Database::Schema).generate

        model_path = File.join(paths[:models], "upload.rb")
        original = File.read(model_path)
        custom_method = <<~RUBY.strip
          def self.create_for_file(path:)
            create(id: path.hash)
          end
        RUBY
        updated =
          original.sub(
            "# -- custom code --\n    # -- end custom code --",
            "# -- custom code --\n    #{custom_method}\n    # -- end custom code --",
          )
        File.write(model_path, updated)

        Migrations::Database::Schema.reset!
        configure_output(tmpdir)
        stub_validation_and_resolution(definition)
        described_class.new(Migrations::Database::Schema).generate

        regenerated = File.read(model_path)
        expect(regenerated).to include("# -- custom code --")
        expect(regenerated).to include("def self.create_for_file(path:)")
        expect(regenerated).to include("# -- end custom code --")
      end
    end

    it "raises when an extended model contains invalid Ruby" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("uploads", model_mode: :extended)
        definition = Migrations::Database::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        FileUtils.mkdir_p(paths[:models])
        File.write(File.join(paths[:models], "upload.rb"), "def broken(\n")

        expect { described_class.new(Migrations::Database::Schema).generate }.to raise_error(
          Migrations::Database::Schema::GenerationError,
          /Failed to parse/,
        )
      end
    end

    it "does not include custom code markers for default mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Database::Schema).generate

        content = File.read(File.join(paths[:models], "user.rb"))
        expect(content).not_to include("# -- custom code --")
        expect(content).not_to include("# -- end custom code --")
      end
    end
  end
end
