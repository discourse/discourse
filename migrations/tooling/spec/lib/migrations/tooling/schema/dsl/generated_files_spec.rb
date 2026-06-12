# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::GeneratedFiles do
  # Minimal stand-ins: ModelWriter.filename_for only reads `name`/`model_mode`,
  # EnumWriter.filename_for only reads `name`.
  def table(name, model_mode = nil)
    Struct.new(:name, :model_mode).new(name, model_mode)
  end

  def enum(name)
    Struct.new(:name).new(name)
  end

  def resolved(tables: [], enums: [])
    Struct.new(:tables, :enums).new(tables, enums)
  end

  # GeneratedFiles only reads the model/enum directories off the output config.
  def output_config(models: "lib/models", enums: "lib/enums")
    Struct.new(:models_directory, :enums_directory).new(models, enums)
  end

  let(:definition) do
    resolved(
      tables: [table("users"), table("uploads", :manual), table("badges", :extended)],
      enums: [enum("visibility")],
    )
  end

  describe ".expected_paths" do
    it "returns absolute model and enum paths rooted at root, excluding manual models" do
      paths = described_class.expected_paths(definition, output_config, "/repo")

      expect(paths).to contain_exactly(
        "/repo/lib/models/user.rb",
        "/repo/lib/models/badge.rb",
        "/repo/lib/enums/visibility.rb",
      )
    end

    it "honours an absolute output directory by ignoring the root" do
      config = output_config(models: "/abs/models", enums: "/abs/enums")

      paths = described_class.expected_paths(definition, config, "/repo")

      expect(paths).to include("/abs/models/user.rb", "/abs/enums/visibility.rb")
    end
  end

  describe ".stale_paths" do
    around do |example|
      Dir.mktmpdir do |dir|
        @root = dir
        FileUtils.mkdir_p(File.join(dir, "lib/models"))
        FileUtils.mkdir_p(File.join(dir, "lib/enums"))
        example.run
      end
    end

    def write(relative, contents)
      File.write(File.join(@root, relative), contents)
    end

    def stale
      config = output_config
      expected = described_class.expected_paths(definition, config, @root)
      described_class.stale_paths(config, @root, expected)
    end

    it "returns generated files that are no longer expected" do
      write("lib/models/user.rb", "# #{described_class::MARKER} ...\n")
      write("lib/models/old.rb", "# #{described_class::MARKER} ...\n")
      write("lib/enums/gone.rb", "# #{described_class::MARKER} ...\n")

      expect(stale).to contain_exactly(
        File.join(@root, "lib/models/old.rb"),
        File.join(@root, "lib/enums/gone.rb"),
      )
    end

    it "ignores files that do not carry the generated marker" do
      write("lib/models/manual.rb", "# hand-written, no marker\n")

      expect(stale).to be_empty
    end

    it "does not report expected files as stale" do
      write("lib/models/user.rb", "# #{described_class::MARKER} ...\n")
      write("lib/models/badge.rb", "# #{described_class::MARKER} ...\n")

      expect(stale).to be_empty
    end
  end
end
