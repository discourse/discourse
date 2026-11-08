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

  it "observes content paths at native conversion time" do
    program = <<~RUBY
      require "json"
      require "tmpdir"
      require "pathname"
      require "set"
      require #{Rails.root.join("script/ci/rspec_file_access").to_s.inspect}
      Dir.mktmpdir do |directory|
        cases = [File, IO].flat_map do |receiver|
          %i[read binread readlines foreach].product(%i[to_path to_str]).map do |operation, protocol|
            [receiver, operation, protocol]
          end
        end
        cases += %i[to_path to_str].map { |protocol| [File, :sysopen, protocol] }
        paths = cases.map do |receiver, operation, protocol|
          name = [receiver.name, operation, protocol].join("_") + ".txt"
          path = File.join(directory, name)
          File.write(path, "content")
          path
        end
        RspecFileAccess.enable(root: directory)
        results = cases.zip(paths).map do |(receiver, operation, protocol), path|
          conversions = 0
          argument = Object.new
          argument.define_singleton_method(protocol) do
            conversions += 1
            raise "Repeated path conversion" if conversions > 1
            path
          end
          value =
            case operation
            when :foreach
              receiver.foreach(argument).to_a.join
            when :readlines
              receiver.readlines(argument).join
            when :sysopen
              stream = IO.new(receiver.sysopen(argument))
              begin
                stream.read
              ensure
                stream.close
              end
            else
              receiver.public_send(operation, argument)
            end
          { value: value, conversions: conversions }
        end
        puts JSON.generate({ results: results, shared: RspecFileAccess.shared_files.sort, expected_paths: paths.map { |path| File.basename(path) }.sort })
      end
    RUBY

    output, status =
      Open3.capture2e(isolated_rspec_environment, "bundle", "exec", "ruby", "-e", program)

    expect(status.success?).to eq(true), output
    result = JSON.parse(output)
    expect(result.fetch("results")).to eq(
      Array.new(18) { { "value" => "content", "conversions" => 1 } },
    )
    expect(result.fetch("shared")).to eq(result.fetch("expected_paths"))
  end

  it "observes native pathname coercion without predicate queries" do
    program = <<~RUBY
      require "json"
      require "tmpdir"
      require "pathname"
      require "set"
      require #{Rails.root.join("script/ci/rspec_file_access").to_s.inspect}
      Dir.mktmpdir do |directory|
        cases = %i[basic hidden].product(%i[read size])
        paths = cases.map do |kind, operation|
          path = File.join(directory, [kind, operation].join("_") + ".txt")
          File.write(path, "metadata")
          path
        end
        RspecFileAccess.enable(root: directory)
        results = cases.zip(paths).map do |(kind, operation), path|
          argument_type = Class.new(kind == :basic ? BasicObject : Object) do
            attr_reader :conversions
            def initialize(path)
              @path = path
              @conversions = 0
            end
            def to_io
              nil
            end
          end
          if kind == :hidden
            argument_type.define_method(:method_missing) do |name, *arguments|
              if name == :to_path
                @conversions += 1
                @path
              else
                super(name, *arguments)
              end
            end
          else
            argument_type.define_method(:to_path) do
              @conversions += 1
              @path
            end
          end
          argument = argument_type.new(path)
          value = File.public_send(operation, argument)
          { value: value, conversions: argument.conversions }
        end
        puts JSON.generate({ results: results, shared: RspecFileAccess.shared_files.sort, metadata: RspecFileAccess.metadata, failure: RspecFileAccess.failure })
      end
    RUBY

    output, status =
      Open3.capture2e(isolated_rspec_environment, "bundle", "exec", "ruby", "-e", program)

    expect(status.success?).to eq(true), output
    result = JSON.parse(output)
    expect(result.fetch("results")).to eq(
      [
        { "value" => "metadata", "conversions" => 1 },
        { "value" => 8, "conversions" => 1 },
        { "value" => "metadata", "conversions" => 1 },
        { "value" => 8, "conversions" => 1 },
      ],
    )
    expect(result.fetch("shared")).to eq(%w[basic_read.txt hidden_read.txt])
    expect(result.fetch("metadata")).to eq(
      "basic_size.txt" => [{ "method" => "size", "value" => 8 }],
      "hidden_size.txt" => [{ "method" => "size", "value" => 8 }],
    )
    expect(result.fetch("failure")).to eq(nil)
  end

  it "preserves native argument validation under actual collection" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/spec/native_arguments_spec.rb", <<~RUBY)
        require "rspec"

        RSpec.describe "Native argument validation" do
          [File, IO].each do |receiver|
            %i[read binread readlines foreach sysopen].each do |operation|
              it "preserves missing arguments for " + receiver.name + "." + operation.to_s do
                expect { receiver.public_send(operation) }.to raise_error(ArgumentError)
              end
            end
            it "preserves keyword-only input for " + receiver.name + ".read" do
              expect { receiver.read(mode: "r") }.to raise_error(ArgumentError)
            end
          end

          %i[realpath realdirpath].each do |operation|
            it "preserves a nil base for " + operation.to_s do
              relative = "spec/native_arguments_spec.rb"
              expect(File.public_send(operation, relative, nil)).to eq(File.expand_path(relative))
            end
          end
        end
      RUBY

      [[], ["--require", Rails.root.join("script/ci/rspec_mapping.rb").to_s]].each do |arguments|
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
            *arguments,
            "spec/native_arguments_spec.rb",
            "--format",
            "json",
            "--out",
            "result.json",
            chdir: directory,
          )

        report = JSON.parse(File.read("#{directory}/result.json"))
        expect(status.success?).to eq(true), "#{output}\n#{report}"
        expect(
          report.fetch("summary").slice(
            "example_count",
            "failure_count",
            "pending_count",
            "errors_outside_of_examples_count",
          ),
        ).to eq(
          "example_count" => 14,
          "failure_count" => 0,
          "pending_count" => 0,
          "errors_outside_of_examples_count" => 0,
        )
      end
      worker = JSON.parse(File.read(Dir["#{directory}/mapping/worker-*.json"].sole))
      expect(worker.fetch("complete")).to eq(true)
    end
  end

  it "preserves a single path conversion when observing file metadata" do
    program = <<~RUBY
      require "json"
      require "tmpdir"
      require "pathname"
      require "set"
      require #{Rails.root.join("script/ci/rspec_file_access").to_s.inspect}
      Dir.mktmpdir do |directory|
        paths = %i[to_path to_str].to_h do |conversion|
          path = File.join(directory, conversion.to_s + ".txt")
          File.write(path, "metadata")
          [conversion, path]
        end
        RspecFileAccess.enable(root: directory)
        results = paths.to_h do |conversion, path|
          argument = Class.new do
            attr_reader :conversions
            def initialize(path)
              @path = path
              @conversions = 0
            end
            define_method(conversion) do
              @conversions += 1
              raise "Repeated path conversion" if @conversions > 1
              @path
            end
          end.new(path)
          value = File.size(argument)
          [conversion, { value: value, conversions: argument.conversions, metadata: RspecFileAccess.metadata.fetch(File.basename(path)) }]
        end
        puts JSON.generate(results)
      end
    RUBY

    output, status =
      Open3.capture2e(isolated_rspec_environment, "bundle", "exec", "ruby", "-e", program)

    expect(status.success?).to eq(true), output
    expect(JSON.parse(output)).to eq(
      "to_path" => {
        "value" => 8,
        "conversions" => 1,
        "metadata" => [{ "method" => "size", "value" => 8 }],
      },
      "to_str" => {
        "value" => 8,
        "conversions" => 1,
        "metadata" => [{ "method" => "size", "value" => 8 }],
      },
    )
  end

  it "observes resolved two argument paths without adding conversions" do
    program = <<~RUBY
      require "json"
      require "tmpdir"
      require "pathname"
      require "set"
      require #{Rails.root.join("script/ci/rspec_file_access").to_s.inspect}
      Dir.mktmpdir do |directory|
        File.write(File.join(directory, "entry.txt"), "x")
        RspecFileAccess.enable(root: directory)
        results = []
        %i[realpath realdirpath].each do |operation|
          %i[to_path to_str].each do |conversion|
            [false, true].each do |absolute|
              counts = { "path" => 0, "base" => 0 }
              arguments = %w[path base].map do |role|
                raw = role == "base" ? directory : absolute ? File.join(directory, "entry.txt") : "entry.txt"
                argument = Object.new
                argument.define_singleton_method(conversion) do
                  counts[role] += 1
                  raise "Observation repeated conversion" if counts[role] > 1
                  raw
                end
                argument
              end
              results << File.public_send(operation, *arguments).delete_prefix(directory + "/")
            end
          end
        end
        puts JSON.generate(results: results, metadata: RspecFileAccess.metadata, failure: RspecFileAccess.failure)
      end
    RUBY

    output, status =
      Open3.capture2e(isolated_rspec_environment, "bundle", "exec", "ruby", "-e", program)

    expect(status.success?).to eq(true), output
    expect(JSON.parse(output)).to eq(
      "results" => ["entry.txt"] * 8,
      "metadata" => {
        "entry.txt" => [
          { "method" => "realpath", "value" => "entry.txt" },
          { "method" => "realdirpath", "value" => "entry.txt" },
        ],
      },
      "failure" => nil,
    )
  end

  it "preserves native descriptor and path dispatch during mapping collection" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/spec/descriptor_spec.rb", <<~'RUBY')
        require "tempfile"
        RSpec.describe "Native file arguments" do
          it "uses the descriptor or pathname chosen by each native operation" do
            temporary = Tempfile.new("metadata-descriptor")
            begin
              temporary.write("one")
              temporary.flush
              temporary.unlink
              expect(File.size(temporary)).to eq(3)
              expect(File.exist?(temporary)).to eq(true)
              temporary.close
              expect { File.size(temporary) }.to raise_error(IOError)
            ensure
              temporary.close
            end
            File.write("descriptor.txt", "one")
            File.write("pathname.txt", "different")
            File.open("descriptor.txt") do |descriptor|
              argument = Object.new
              argument.define_singleton_method(:to_io) { descriptor }
              argument.define_singleton_method(:to_path) { "pathname.txt" }
              expect(File.size(argument)).to eq(3)
              expect(FileTest.size(argument)).to eq(3)
              expect(test(?s, argument)).to eq(9)
              expect(File.stat(argument).size).to eq(9)
            end
          end
        end
      RUBY
      File.write("#{directory}/spec/path_spec.rb", <<~'RUBY')
        require "json"
        require "tmpdir"
        RSpec.describe "Native repeated path conversion" do
          it "returns the modification time chosen by the native operation" do
            Dir.mktmpdir do |directory|
              paths = %w[first second].map { |name| File.join(directory, name) }
              paths.each_with_index { |path, index| File.write(path,"x"); File.utime(100 + index * 100, 100 + index * 100, path) }
              conversions = []
              argument = Object.new
              argument.define_singleton_method(:to_path) { conversions << "to_path"; paths[[conversions.count("to_path") - 1,1].min] }
              argument.define_singleton_method(:to_io) { conversions << "to_io"; nil }
              result = Kernel.test("M", argument)
              File.write("conversion.json", JSON.generate({"mtime" => result.to_i, "conversions" => conversions}))
              expect(result.to_i).to eq(200)
            end
          end
        end
      RUBY
      [false, true].each do |collect|
        arguments = collect ? ["--require", Rails.root.join("script/ci/rspec_mapping.rb").to_s] : []
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
            *arguments,
            "spec/descriptor_spec.rb",
            "spec/path_spec.rb",
            "--format",
            "json",
            "--out",
            "result.json",
            chdir: directory,
          )

        report = JSON.parse(File.read("#{directory}/result.json"))
        expect(status.success?).to eq(true), "#{output}\n#{report}"
        expect(report.fetch("summary").slice("example_count", "failure_count")).to eq(
          "example_count" => 2,
          "failure_count" => 0,
        )
        expect(JSON.parse(File.read("#{directory}/conversion.json"))).to eq(
          "mtime" => 200,
          "conversions" => %w[to_path to_io to_path],
        )
      end
      worker = JSON.parse(File.read(Dir["#{directory}/mapping/worker-*.json"].sole))
      expect(worker.fetch("complete")).to eq(true)
      expect(worker.fetch("file_metadata").fetch("descriptor.txt")).to include(
        "method" => "size",
        "value" => 3,
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
