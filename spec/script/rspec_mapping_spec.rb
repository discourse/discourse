# frozen_string_literal: true

require "rails_helper"
require "crystalball"
require "open3"
require "tmpdir"
require_relative "../support/rspec_subprocess_environment"
require_relative "../../script/ci/rspec_source_structure"
require_relative "../../script/ci/rspec_file_metadata"
require_relative "../../script/ci/dependency_graph"

RSpec.describe Crystalball do
  include RSpecSubprocessEnvironment
  it "records outer setup and nested shared examples against the including spec" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/spec/support")
      FileUtils.mkdir_p("#{directory}/lib")
      File.write("#{directory}/lib/boot.txt", "42")
      File.write("#{directory}/lib/data.txt", "42")
      File.write("#{directory}/lib/metadata.txt", "metadata")
      File.symlink("data.txt", "#{directory}/lib/data-link.txt")
      File.write(
        "#{directory}/lib/definition.rb",
        "class Definition\n  VALUE = 42\n  BOOT = File.read(File.expand_path(\"boot.txt\", __dir__))\n  SIZE = File.size(File.expand_path(\"metadata.txt\", __dir__))\n  EXISTS = FileTest.file?(File.expand_path(\"metadata.txt\", __dir__))\nend\n",
      )
      File.write("#{directory}/lib/setup.rb", <<~RUBY)
        module Setup
          def self.value
            42.to_s
          end
        end
      RUBY
      File.write("#{directory}/lib/body.rb", <<~RUBY)
        module Body
          def self.value
            File.open(Pathname.new(File.expand_path("data-link.txt", __dir__)), &:read)
          end
        end
      RUBY
      File.write("#{directory}/spec/support/shared.rb", <<~RUBY)
        RSpec.shared_examples "a value" do
          it "computes a value" do
            expect(Body.value).to eq("42")
            expect(Object.new.respond_to?(:test)).to eq(false)
            expect(Kernel.respond_to?(:test)).to eq(true)
          end
        end
      RUBY
      File.write("#{directory}/spec/example_spec.rb", <<~RUBY)
        require_relative "../lib/setup"
        require_relative "../lib/body"
        require_relative "../lib/definition"
        require_relative "support/shared"
        RSpec.describe Definition do
          before(:context) { Setup.value }
          context "nested" do
            it_behaves_like "a value"
          end
        end
      RUBY

      File.write("#{directory}/spec/skipped_spec.rb", <<~RUBY)
        RSpec.describe "skipped", skip: true do
          it("waits") { expect(1).to eq(1) }
        end
        RSpec.configure do |config|
          config.prepend_after(:suite) do
            RSpec.describe "a group registered after execution" do
              it("was not scheduled") { expect(false).to eq(true) }
            end
          end
        end
      RUBY

      output, status =
        Open3.capture2e(
          isolated_rspec_environment.merge(
            "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
            "GITHUB_SHA" => "a" * 40,
            "RSPEC_MAPPING_DIRECTORY" => "#{directory}/mapping",
          ),
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--require",
          Rails.root.join("script/ci/rspec_mapping.rb").to_s,
          "spec/example_spec.rb",
          "spec/skipped_spec.rb",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      worker = JSON.parse(File.read(Dir["#{directory}/mapping/worker-*.json"].sole))
      expect(worker["complete"]).to eq(true)
      expect(worker["dependencies"].keys).to eq(["spec/example_spec.rb"])
      expect(worker["shared_files"]).to include("lib/boot.txt", "lib/data.txt", "lib/data-link.txt")
      expect(worker["shared_files"]).not_to include(
        "lib/setup.rb",
        "lib/body.rb",
        "lib/definition.rb",
        "lib/metadata.txt",
      )
      expect(worker.fetch("file_metadata").fetch("lib/metadata.txt")).to include(
        { "method" => "size", "value" => 8 },
        { "method" => "file?", "value" => true },
      )
      expect(worker["dependencies"]["spec/example_spec.rb"]).to include(
        "lib/setup.rb",
        "lib/body.rb",
        "lib/definition.rb",
        "spec/support/shared.rb",
      )
    end
  end

  it "retains declarations and code executed during boot when validating source changes" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      original = "class Example\n  VALUE = 42\n  def self.value\n    VALUE.to_s\n  end\nend\n"
      File.write(path, original)
      description = RspecSourceStructure.describe(path)
      File.write(path, original.sub("VALUE.to_s", "return \"changed\"\n    VALUE.to_s"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original.sub("VALUE.to_s", "VALUE.to_i"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original.sub("VALUE.to_s", "@cached = VALUE.to_s"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original.sub("VALUE.to_s", "public_send(:first)"))
      reflective = RspecSourceStructure.describe(path)
      File.write(path, original.sub("VALUE.to_s", "public_send(:second)"))
      expect(RspecSourceStructure.matches?(path:, description: reflective)).to eq(false)
      File.write(path, original.sub("42", "43"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original)
      description = RspecSourceStructure.describe(path, boot_lines: [4])
      File.write(path, original.sub("VALUE.to_s", "VALUE.to_i"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original.sub("def self.value", "def self.value(argument)"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "preserves literal types when reusing a method mapping" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      File.write(path, "def value; :original; end")
      description = RspecSourceStructure.describe(path)

      File.write(path, "def value; :changed; end")
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(true)
      File.write(path, 'def value; "changed"; end')
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "compares only the observed file metadata" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      File.write(path, "one")
      kind = RspecFileMetadata.describe(method: :file?, value: File.file?(path))
      size = RspecFileMetadata.describe(method: :size, value: File.size(path))

      File.write(path, "a longer value")

      expect(RspecFileMetadata.matches?(path: path, descriptions: [kind])).to eq(true)
      expect(RspecFileMetadata.matches?(path: path, descriptions: [size])).to eq(false)
    end
  end

  it "rejects an unsupported metadata reader without changing the file" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      original = "original"
      File.write(path, original)

      result =
        RspecFileMetadata.matches?(
          path: path,
          descriptions: [{ "method" => "unlink", "value" => true }],
        )

      expect(result).to eq(false)
      expect(File.read(path)).to eq(original)
    end
  end

  it "invalidates an early return before Unicode receiver calls" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      File.write(path, 'def value; "é".upcase; end')
      description = RspecSourceStructure.describe(path)

      File.write(path, 'def value; return "changed"; "é".upcase; end')

      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "protects source positions observed during initialization" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      original =
        "module Example\n def self.unused\n  :original\n  :unused\n end\n VALUE = binding.source_location.last\nend\n"
      File.write(path, original)
      description = RspecSourceStructure.describe(path)

      File.write(path, original.sub(":original\n  :unused", ":original\n\n  :unused"))

      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "invalidates changed control flow and dispatch inputs" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      [
        "if true; WriterA.populate; else; WriterB.populate; end",
        "enabled = true; if enabled; WriterA.populate; else; WriterB.populate; end",
        "false && WriterA.populate",
        "true || WriterA.populate",
        "return true; WriterA.populate",
      ].each do |body|
        original = "def populate; #{body}; end"
        File.write(path, original)
        description = RspecSourceStructure.describe(path)

        File.write(
          path,
          (
            if original.include?("false &&")
              original.sub("false", "true")
            else
              original.sub("true", "false")
            end
          ),
        )

        expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      end
    end
  end

  it "permits a different method to change while protecting initialization effects" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      original =
        "module Example\n def self.initialize_routes\n  class_eval(\"\")\n end\n def self.value\n  :original\n end\nend\n"
      File.write(path, original)
      description = RspecSourceStructure.describe(path, boot_lines: [3])

      File.write(path, original.sub(":original", ":changed"))

      expect(RspecSourceStructure.matches?(path:, description:)).to eq(true)
      File.write(path, original.sub('class_eval("")', 'class_eval("define_method(:extra) {}")'))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "keeps every producer when a shared cache has many inputs" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/lib")
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/lib/cache.rb", <<~RUBY)
        module ManySourceCache
          @values = {}
          def self.values
            @values
          end
        end
      RUBY
      96.times { |index| File.write("#{directory}/lib/producer_#{index}.rb", <<~RUBY) }
          module MappedProducer#{index}
            def self.value
              #{index}
            end
          end
        RUBY
      requires = 96.times.map { |index| "require_relative \"../lib/producer_#{index}\"" }.join("\n")
      writes =
        96
          .times
          .map { |index| "ManySourceCache.values[:key#{index}] = MappedProducer#{index}.value" }
          .join("\n")
      File.write("#{directory}/spec/writer_spec.rb", <<~RUBY)
        require_relative "../lib/cache"
        #{requires}
        RSpec.describe "writer" do
          it "fills the shared cache" do
            #{writes}
          end
        end
      RUBY
      File.write("#{directory}/spec/reader_spec.rb", <<~RUBY)
        require_relative "../lib/cache"
        RSpec.describe "reader" do
          it "reads the shared cache" do
            expect(ManySourceCache.values.fetch(:key95)).to eq(95)
          end
        end
      RUBY

      output, status =
        Open3.capture2e(
          isolated_rspec_environment.merge(
            "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
            "GITHUB_SHA" => "a" * 40,
            "RSPEC_MAPPING_DIRECTORY" => "#{directory}/mapping",
          ),
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--order",
          "defined",
          "--require",
          Rails.root.join("script/ci/rspec_mapping.rb").to_s,
          "spec/writer_spec.rb",
          "spec/reader_spec.rb",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      worker = JSON.parse(File.read(Dir["#{directory}/mapping/worker-*.json"].sole))
      expected = 96.times.map { |index| "__method__/lib/producer_#{index}.rb/0" }
      expect(worker["complete"]).to eq(true)
      graph =
        TestSelection::DependencyGraph.new(
          serialized: worker.fetch("dependency_graph"),
          tests: worker.fetch("tests"),
        )
      affected =
        expected.select do |source|
          graph.affected_sources([source]).include?("__state__/class/ManySourceCache/@values")
        end
      expect(affected).to eq(expected)
    end
  end
end
