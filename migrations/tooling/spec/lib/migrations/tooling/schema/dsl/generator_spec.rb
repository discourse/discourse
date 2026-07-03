# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::Generator do
  # Generation writes files to the configured output paths. Run every example
  # from a throwaway working directory so a stray relative path can never drop a
  # generated file into the repo -- e.g. under mutation, where a dropped
  # directory prefix would otherwise scribble `user.rb` into the gem root.
  around { |example| Dir.mktmpdir { |cwd| Dir.chdir(cwd) { example.run } } }

  after { Migrations::Tooling::Schema.reset! }

  def make_table(name, model_mode: nil, conflict_strategy: :raise)
    Migrations::Tooling::Schema::TableDefinition.new(
      name:,
      conflict_strategy:,
      columns: [
        Migrations::Tooling::Schema::ColumnDefinition.new(
          name: "id",
          datatype: :integer,
          nullable: false,
          max_length: nil,
          is_primary_key: true,
          enum: nil,
        ),
        Migrations::Tooling::Schema::ColumnDefinition.new(
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
      Migrations::Tooling::Schema::EnumDefinition.new(
        name: "visibility",
        values: {
          "public" => 0,
          "private" => 1,
        },
        datatype: :integer,
      )

    Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [enum])
  end

  def stub_validation_and_resolution(definition)
    allow(Migrations::Tooling::Schema).to receive(:preflight).and_return(
      Migrations::Tooling::Schema::PreflightResult.new(resolved: definition, errors: []),
    )

    allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_files)
  end

  def configure_output(tmpdir)
    sql_path = File.join(tmpdir, "schema.sql")
    models_path = File.join(tmpdir, "models")
    enums_path = File.join(tmpdir, "enums")

    Migrations::Tooling::Schema.configure do
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

        allow(Migrations::Tooling::Schema).to receive(:preflight).and_return(
          Migrations::Tooling::Schema::PreflightResult.new(
            resolved: nil,
            errors: ["Table 'users': bad config"],
          ),
        )

        expect { described_class.new(Migrations::Tooling::Schema).generate }.to raise_error(
          Migrations::Tooling::Schema::GenerationError,
          /Schema validation failed with 1 error:/,
        )
      end
    end

    it "lists every validation error and pluralizes the count" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)

        allow(Migrations::Tooling::Schema).to receive(:preflight).and_return(
          Migrations::Tooling::Schema::PreflightResult.new(
            resolved: nil,
            errors: ["Table 'a': first problem", "Table 'b': second problem"],
          ),
        )

        expect { described_class.new(Migrations::Tooling::Schema).generate }.to raise_error(
          Migrations::Tooling::Schema::GenerationError,
        ) do |error|
          expect(error.message).to eq(<<~MESSAGE.chomp)
            Schema validation failed with 2 errors:
              - Table 'a': first problem
              - Table 'b': second problem
          MESSAGE
        end
      end
    end

    it "generates SQL, model, and enum files" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        generator = described_class.new(Migrations::Tooling::Schema)
        result = generator.generate

        expect(result).to eq(resolved_definition)
        expect(File.exist?(paths[:sql])).to be true
        expect(Dir.exist?(paths[:models])).to be true
        expect(Dir.exist?(paths[:enums])).to be true

        sql_content = File.read(paths[:sql])
        expect(sql_content).to include("This file is auto-generated from the")
        expect(sql_content).to include("CREATE TABLE users")
        expect(sql_content).to include("id")
        expect(sql_content).to include("username")

        model_files = Dir[File.join(paths[:models], "*.rb")]
        expect(model_files.size).to eq(1)
        expect(File.basename(model_files.first)).to eq("user.rb")

        enum_files = Dir[File.join(paths[:enums], "*.rb")]
        expect(enum_files.size).to eq(1)
        expect(File.basename(enum_files.first)).to eq("visibility.rb")

        enum_content = File.read(enum_files.first)
        expect(enum_content).to include("module Enums")
        expect(enum_content).to include("PUBLIC = 0")
        expect(enum_content).to include("PRIVATE = 1")
      end
    end

    it "passes the configured database through to preflight" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Tooling::Schema).generate

        expect(Migrations::Tooling::Schema).to have_received(:preflight).with(
          database: :intermediate_db,
        )
      end
    end

    it "expands paths against output_root and reports deletions relative to it" do
      Dir.mktmpdir do |tmpdir|
        Migrations::Tooling::Schema.configure do
          output do
            # Nested, non-existent directory so the `mkdir_p` is load-bearing.
            schema_file "db/schema.sql"
            models_directory "models"
            models_namespace "Test::Models"
            enums_directory "enums"
            enums_namespace "Test::Enums"
          end
        end
        stub_validation_and_resolution(resolved_definition)

        expect(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_files).with(
          File.join(tmpdir, "models"),
        )
        expect(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_files).with(
          File.join(tmpdir, "enums"),
        )

        FileUtils.mkdir_p(File.join(tmpdir, "models"))
        stale = File.join(tmpdir, "models", "old_model.rb")
        File.write(stale, "# This file is auto-generated from the Models schema.\n")

        generator = described_class.new(Migrations::Tooling::Schema, output_root: tmpdir)
        generator.generate

        expect(File.exist?(File.join(tmpdir, "db", "schema.sql"))).to be true
        expect(File.exist?(File.join(tmpdir, "models", "user.rb"))).to be true
        expect(File.exist?(File.join(tmpdir, "enums", "visibility.rb"))).to be true
        expect(File.exist?(stale)).to be false
        expect(generator.deleted_files).to eq(["models/old_model.rb"])
      end
    end

    it "uses the configured namespace in model insert calls" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Tooling::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("Test::Models.insert(")
      end
    end

    it "derives header label from models_namespace" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Tooling::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("auto-generated from the Models schema")
      end
    end

    it "does not write model file for :manual mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("log_entries", model_mode: :manual)
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        generator = described_class.new(Migrations::Tooling::Schema)
        generator.generate

        expect(Dir[File.join(paths[:models], "*.rb")]).to be_empty
        # A manual table must be skipped outright, not written and then removed
        # as a stale file.
        expect(generator.deleted_files).to be_empty
      end
    end

    it "still generates later models when an earlier table is :manual" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        manual = make_table("log_entries", model_mode: :manual)
        normal = make_table("users")
        definition =
          Migrations::Tooling::Schema::Definition.new(tables: [manual, normal], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Tooling::Schema).generate

        expect(File.exist?(File.join(paths[:models], "log_entry.rb"))).to be false
        expect(File.exist?(File.join(paths[:models], "user.rb"))).to be true
      end
    end

    it "generates a plain `INSERT` and no conflict strategy for the default `:raise`" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Tooling::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("INSERT INTO users")
        expect(model_content).not_to include("INSERT OR IGNORE")
        expect(model_content).not_to include("def self.conflict_strategy")
      end
    end

    it "generates `INSERT OR IGNORE` and a conflict strategy for `:ignore`" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("users", conflict_strategy: :ignore)
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Tooling::Schema).generate

        model_content = File.read(File.join(paths[:models], "user.rb"))
        expect(model_content).to include("INSERT OR IGNORE INTO users")
        expect(model_content).to include("def self.conflict_strategy")
        expect(model_content).to include(":ignore")
      end
    end

    it "does not create a model file for :manual mode even when models directory exists" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("log_entries", model_mode: :manual)
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        FileUtils.mkdir_p(paths[:models])

        described_class.new(Migrations::Tooling::Schema).generate

        expect(File.exist?(File.join(paths[:models], "log_entry.rb"))).to be false
      end
    end

    it "deletes generated files that are no longer produced" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        FileUtils.mkdir_p(paths[:models])
        stale_path = File.join(paths[:models], "old_model.rb")
        File.write(stale_path, "# This file is auto-generated from the Models schema.\n")

        generator = described_class.new(Migrations::Tooling::Schema)
        generator.generate

        expect(File.exist?(stale_path)).to be false
        expect(generator.deleted_files.size).to eq(1)
        # The stale file lives outside the default output_root (the repository
        # root), so its display path stays absolute rather than a `../…` string.
        expect(generator.deleted_files.first).to eq(stale_path)
      end
    end

    it "keeps files without the auto-generated header" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        FileUtils.mkdir_p(paths[:models])
        manual_path = File.join(paths[:models], "manual_model.rb")
        File.write(manual_path, "# Hand-written model\n")

        generator = described_class.new(Migrations::Tooling::Schema)
        generator.generate

        expect(File.exist?(manual_path)).to be true
        expect(generator.deleted_files).to be_empty
      end
    end

    it "generates model file with custom code markers for :extended mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("uploads", model_mode: :extended)
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Tooling::Schema).generate

        content = File.read(File.join(paths[:models], "upload.rb"))
        expect(content).to include("# -- custom code --")
        expect(content).to include("# -- end custom code --")
      end
    end

    it "preserves custom code between markers on regeneration for :extended mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        table = make_table("uploads", model_mode: :extended)
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Tooling::Schema).generate

        model_path = File.join(paths[:models], "upload.rb")
        original = File.read(model_path)
        custom_method = <<~RUBY
          def self.create_for_file(path:)
            create(id: path.hash)
          end
        RUBY
        updated =
          original.sub(
            /# -- custom code --\n(\s*)# -- end custom code --/,
            "# -- custom code --\n#{custom_method}\\1# -- end custom code --",
          )
        File.write(model_path, updated)

        Migrations::Tooling::Schema.reset!
        configure_output(tmpdir)
        stub_validation_and_resolution(definition)
        described_class.new(Migrations::Tooling::Schema).generate

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
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
        stub_validation_and_resolution(definition)

        FileUtils.mkdir_p(paths[:models])
        File.write(File.join(paths[:models], "upload.rb"), "def broken(\n")

        expect { described_class.new(Migrations::Tooling::Schema).generate }.to raise_error(
          Migrations::Tooling::Schema::GenerationError,
        ) do |error|
          expect(error.message).to start_with("Failed to parse")
          # Each parse error is formatted as a bullet carrying its line number.
          expect(error.message).to match(/\n {2}- .+ \(line 1\)/)
        end
      end
    end

    it "does not include custom code markers for default mode" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)

        described_class.new(Migrations::Tooling::Schema).generate

        content = File.read(File.join(paths[:models], "user.rb"))
        expect(content).not_to include("# -- custom code --")
        expect(content).not_to include("# -- end custom code --")
      end
    end

    it "references the enums namespace for enum-backed columns" do
      Dir.mktmpdir do |tmpdir|
        paths = configure_output(tmpdir)

        enum =
          Migrations::Tooling::Schema::EnumDefinition.new(
            name: "visibility",
            values: {
              "public" => 0,
              "private" => 1,
            },
            datatype: :integer,
          )
        table =
          Migrations::Tooling::Schema::TableDefinition.new(
            name: "users",
            conflict_strategy: :raise,
            columns: [
              Migrations::Tooling::Schema::ColumnDefinition.new(
                name: "id",
                datatype: :integer,
                nullable: false,
                max_length: nil,
                is_primary_key: true,
                enum: nil,
              ),
              Migrations::Tooling::Schema::ColumnDefinition.new(
                name: "visibility",
                datatype: :integer,
                nullable: false,
                max_length: nil,
                is_primary_key: false,
                enum:,
              ),
            ],
            indexes: [],
            primary_key_column_names: ["id"],
            constraints: [],
            model_mode: nil,
          )
        definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [enum])
        stub_validation_and_resolution(definition)

        described_class.new(Migrations::Tooling::Schema).generate

        content = File.read(File.join(paths[:models], "user.rb"))
        expect(content).to include("Test::Enums::Visibility")
      end
    end

    it "still succeeds when formatting raises" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)
        stub_validation_and_resolution(resolved_definition)
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_files).and_raise(
          StandardError.new("stree blew up"),
        )

        expect(described_class.new(Migrations::Tooling::Schema).generate).to eq(resolved_definition)
      end
    end
  end

  describe "#extract_custom_code (private)" do
    def extract(content)
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)
        path = File.join(tmpdir, "model.rb")
        File.write(path, content)
        described_class.new(Migrations::Tooling::Schema).send(:extract_custom_code, path)
      end
    end

    it "returns nil when the file does not exist" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)
        generator = described_class.new(Migrations::Tooling::Schema)
        expect(generator.send(:extract_custom_code, File.join(tmpdir, "missing.rb"))).to be_nil
      end
    end

    it "returns exactly the bytes between the markers" do
      # A comment sits both before the start marker and after the end marker, so
      # the markers must be located with `find` (not `first`/`last`). The leading
      # comment holds a multi-byte character (é) so the marker's byte offset
      # differs from its character offset — the slicing has to work on bytes.
      content =
        "# café – leading note\n" \
          "module M\n" \
          "  # -- custom code --\n" \
          "  def foo; end\n" \
          "  # -- end custom code --\n" \
          "  # trailing note\n" \
          "end\n"
      expect(extract(content)).to eq("  def foo; end\n  ")
    end

    it "returns nil when nothing sits between the markers" do
      content = "module M\n  # -- custom code --\n  # -- end custom code --\nend\n"
      expect(extract(content)).to be_nil
    end

    it "returns nil when the start marker is missing" do
      expect(extract("module M\nend\n")).to be_nil
    end

    it "returns nil when only an end marker is present" do
      # Guards against dereferencing a missing start comment while looking for
      # the end marker.
      content = "module M\n  # -- end custom code --\nend\n"
      expect(extract(content)).to be_nil
    end

    it "returns nil when the end marker is missing" do
      content = "module M\n  # -- custom code --\n  def foo; end\nend\n"
      expect(extract(content)).to be_nil
    end

    it "keeps a comment inside the custom block and stops at the end marker" do
      # The inner comment's offset is past the start marker, so the end finder
      # must still match on the end marker's text rather than the first later
      # comment.
      content =
        "module M\n" \
          "  # -- custom code --\n" \
          "  # an inner comment\n" \
          "  def foo; end\n" \
          "  # -- end custom code --\n" \
          "end\n"
      expect(extract(content)).to eq("  # an inner comment\n  def foo; end\n  ")
    end

    it "ignores an end marker that appears before the start marker" do
      content =
        "module M\n" \
          "  # -- end custom code --\n" \
          "  # -- custom code --\n" \
          "  def foo; end\n" \
          "  # -- end custom code --\n" \
          "end\n"
      expect(extract(content)).to eq("  def foo; end\n  ")
    end

    it "raises with a per-error bullet carrying the line number for invalid Ruby" do
      Dir.mktmpdir do |tmpdir|
        configure_output(tmpdir)
        path = File.join(tmpdir, "model.rb")
        File.write(path, "def broken(\n")

        generator = described_class.new(Migrations::Tooling::Schema)

        # `def broken(` yields several parse errors; build the expectation from
        # Prism itself so the exact bullet format (message + line, one per line,
        # prefixed with the file path) is pinned down.
        bullets =
          Prism
            .parse(File.read(path))
            .errors
            .map { |e| "  - #{e.message} (line #{e.location.start_line})" }
        expect(bullets.size).to be > 1
        expected = "Failed to parse '#{path}':\n#{bullets.join("\n")}"

        expect { generator.send(:extract_custom_code, path) }.to raise_error(
          Migrations::Tooling::Schema::GenerationError,
          expected,
        )
      end
    end
  end

  describe "#generate for :extended models" do
    it "reads custom code from the committed source tree, not the output root" do
      Dir.mktmpdir do |source_root|
        Dir.mktmpdir do |out_root|
          allow(Migrations).to receive(:root_path).and_return(source_root)

          Migrations::Tooling::Schema.configure do
            output do
              schema_file "schema.sql"
              models_directory "models"
              models_namespace "Test::Models"
              enums_directory "enums"
              enums_namespace "Test::Enums"
            end
          end

          table = make_table("uploads", model_mode: :extended)
          definition = Migrations::Tooling::Schema::Definition.new(tables: [table], enums: [])
          stub_validation_and_resolution(definition)

          FileUtils.mkdir_p(File.join(source_root, "models"))
          File.write(
            File.join(source_root, "models", "upload.rb"),
            "module M\n" \
              "  # -- custom code --\n" \
              "  def self.committed_helper; end\n" \
              "  # -- end custom code --\n" \
              "end\n",
          )

          described_class.new(Migrations::Tooling::Schema, output_root: out_root).generate

          content = File.read(File.join(out_root, "models", "upload.rb"))
          expect(content).to include("def self.committed_helper")
        end
      end
    end
  end
end
