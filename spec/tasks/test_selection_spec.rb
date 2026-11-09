# frozen_string_literal: true
require "digest"
require "json"
require "tmpdir"
require "open3"
require "rbconfig"
require_relative "../support/rspec_subprocess_environment"
require_relative "../../script/ci/test_selection"
require_relative "../../script/ci/ruby_dependencies"
require_relative "../../script/ci/test_execution"
require_relative "../../script/ci/test_mapping"
require_relative "../../script/ci/test_job"
require_relative "../../script/ci/test_inventory"
require_relative "../../script/ci/test_plan"
require_relative "../../script/ci/test_mapping_due"

RSpec.describe TestSelection do
  let(:input) do
    {
      "revision" => "b" * 40,
      "mode" => "select",
      "main" => false,
      "changes" => ["lib/shared.rb"],
      "test_changes" => [],
      "deleted_tests" => [],
      "jobs" => {
        "backend" => {
          "inventory" => %w[spec/a_spec.rb spec/b_spec.rb spec/unrelated_spec.rb],
          "environment" => "core",
          "mapping_changes" => [],
          "verified_sources" => %w[lib/shared.rb lib/producer.rb],
          "mapping" => {
            "version" => 2,
            "complete" => true,
            "revision" => "a" * 40,
            "environment" => "core",
            "tests" => {
              "spec/a_spec.rb" => ["lib/shared.rb"],
              "spec/b_spec.rb" => ["lib/reader.rb"],
              "spec/unrelated_spec.rb" => ["lib/unrelated.rb"],
            },
            "sources" => %w[lib/shared.rb lib/reader.rb lib/producer.rb lib/unrelated.rb],
            "source_dependencies" => {
              "lib/reader.rb" => ["lib/producer.rb"],
            },
            "initialization_sources" => [],
            "shared_files" => ["config/application.rb"],
          },
        },
        "browser" => {
          "inventory" => ["frontend/tests/a-test.js"],
          "environment" => "browser",
          "mapping_changes" => [],
          "verified_sources" => [],
          "mapping" => nil,
        },
      },
    }
  end

  it "selects dependent files before routing without adding their neighbours" do
    input["jobs"].delete("browser")

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(["spec/a_spec.rb"])
    expect(result.fetch("jobs")).to eq("backend" => ["spec/a_spec.rb"])
  end

  it "runs only an added spec despite application changes since an older mapping" do
    input["changes"] = ["spec/new_spec.rb"]
    input["test_changes"] = ["spec/new_spec.rb"]
    input["jobs"]["backend"]["inventory"] << "spec/new_spec.rb"
    input["jobs"]["backend"]["mapping_changes"] = ["lib/shared.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(["spec/new_spec.rb"])
    expect(result.fetch("jobs")).to eq("backend" => ["spec/new_spec.rb"], "browser" => [])
  end

  it "routes a selected file to every required environment owner" do
    input["changes"] = ["spec/a_spec.rb"]
    input["test_changes"] = input["changes"]
    input["jobs"]["multisite"] = input["jobs"]["backend"].merge("inventory" => ["spec/a_spec.rb"])

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(["spec/a_spec.rb"])
    expect(result.fetch("jobs")).to eq(
      "backend" => ["spec/a_spec.rb"],
      "browser" => [],
      "multisite" => ["spec/a_spec.rb"],
    )
  end

  it "validates global ownership before assigning files to the current workflow" do
    input["changes"] = %w[spec/a_spec.rb migrations/core/spec/import_spec.rb]
    input["test_changes"] = input["changes"]
    input["global_inventory"] = input["jobs"].values.flat_map { |job| job.fetch("inventory") } +
      ["migrations/core/spec/import_spec.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(["spec/a_spec.rb"])
    expect(result.fetch("jobs")).to eq("backend" => ["spec/a_spec.rb"], "browser" => [])
  end

  it "follows application dependencies through a cached reader" do
    input["jobs"].delete("browser")
    input["changes"] = ["lib/producer.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(["spec/b_spec.rb"])
    expect(result.fetch("reasons")["spec/b_spec.rb"]).to include("Dependency: lib/reader.rb")
  end

  it "broadens when a changed producer populated globally cached initialization values" do
    input["jobs"].delete("browser")
    input["changes"] = ["lib/producer.rb"]
    input["jobs"]["backend"]["mapping"]["initialization_sources"] = ["lib/producer.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(input["jobs"]["backend"]["inventory"])
    expect(result.fetch("reasons")["spec/unrelated_spec.rb"]).to eq(
      ["backend: Initialization input: lib/producer.rb"],
    )
  end

  it "broadens when a changed producer reaches an initialization input through the graph" do
    input["jobs"].delete("browser")
    input["changes"] = ["lib/producer.rb"]
    input["jobs"]["backend"]["mapping"]["initialization_sources"] = ["lib/reader.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(input["jobs"]["backend"]["inventory"])
    expect(result.fetch("reasons")["spec/unrelated_spec.rb"]).to eq(
      ["backend: Initialization input: lib/reader.rb"],
    )
  end

  it "includes mapping drift when the PR changes application code" do
    input["jobs"].delete("browser")
    input["changes"] = ["lib/producer.rb"]
    input["jobs"]["backend"]["mapping_changes"] = ["lib/shared.rb"]

    expect(described_class::Planner.new(input).plan.fetch("files")).to eq(
      %w[spec/a_spec.rb spec/b_spec.rb],
    )
  end

  it "runs a test added on main since mapping without expanding the entire job" do
    input["jobs"].delete("browser")
    input["jobs"]["backend"]["inventory"] << "spec/main_added_spec.rb"
    input["jobs"]["backend"]["mapping_changes"] = ["spec/main_added_spec.rb"]

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(%w[spec/a_spec.rb spec/main_added_spec.rb])
  end

  it "permits a valid empty assignment after deleting a test" do
    input["changes"] = ["spec/a_spec.rb"]
    input["test_changes"] = input["changes"]
    input["deleted_tests"] = input["changes"]
    input["jobs"]["backend"]["inventory"].delete("spec/a_spec.rb")

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq([])
    expect(result.fetch("jobs")).to eq("backend" => [], "browser" => [])
  end

  it "explains broader selection when evidence is missing" do
    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(%w[frontend/tests/a-test.js spec/a_spec.rb])
    expect(result.fetch("reasons")["frontend/tests/a-test.js"]).to eq(
      ["browser: Missing or incompatible mapping"],
    )
  end

  it "runs the full inventory for main" do
    input["main"] = true

    result = described_class::Planner.new(input).plan

    expect(result.fetch("files")).to eq(
      %w[frontend/tests/a-test.js spec/a_spec.rb spec/b_spec.rb spec/unrelated_spec.rb],
    )
  end

  it "rejects changed tests without a current owner" do
    input["changes"] = ["spec/missing_spec.rb"]
    input["test_changes"] = input["changes"]

    expect { described_class::Planner.new(input).plan }.to raise_error(ArgumentError, /owner/)
  end

  it "removes stale output when the CLI receives invalid input" do
    Dir.mktmpdir("test-selection-") do |directory|
      source = File.join(directory, "input.json")
      output = File.join(directory, "plan.json")
      File.write(source, "invalid JSON")
      File.write(output, "old plan")

      _, _, status =
        Open3.capture3(
          RbConfig.ruby,
          File.expand_path("../../script/ci/test_selection.rb", __dir__),
          "plan",
          source,
          output,
        )

      expect(status.success?).to eq(false)
      expect(File.exist?(output)).to eq(false)
    end
  end
end

RSpec.describe TestSelection::RubyDependencies do
  include RSpecSubprocessEnvironment

  it "collects an application receiver without dispatching its identity override" do
    Dir.mktmpdir("receiver-identity-") do |root|
      FileUtils.mkdir_p("#{root}/spec")
      File.write("#{root}/spec/identity_spec.rb", <<~RUBY)
        class FilePlanIdentityArray < Array
          def equal?(_other)
            raise "Collector dispatched the receiver identity method"
          end
        end
        FilePlanIdentityArray.new.clear
      RUBY
      collector = described_class.new(root: root)
      collector.start
      collector.begin_test("spec/identity_spec.rb")
      result = load "#{root}/spec/identity_spec.rb"
      collector.finish_test
      collector.stop

      expect(result).to eq(true)
      expect(collector.snapshot.fetch("tests").keys).to eq(["spec/identity_spec.rb"])
    ensure
      collector&.stop
      Object.send(:remove_const, :FilePlanIdentityArray) if defined?(FilePlanIdentityArray)
    end
  end

  def selected_for_producer(snapshot)
    inventory = snapshot.fetch("tests").keys.sort
    sources =
      (
        snapshot.fetch("observed_sources", []) + snapshot.fetch("tests").values.flatten +
          snapshot.fetch("source_dependencies").keys +
          snapshot.fetch("source_dependencies").values.flatten
      ).uniq.reject { |path| path.start_with?("__state__/", "__method__/") }
    mapping =
      snapshot.merge(
        "version" => 2,
        "complete" => true,
        "revision" => "a" * 40,
        "environment" => "core",
        "sources" => sources,
        "shared_files" => [],
      )
    input = {
      "revision" => "b" * 40,
      "mode" => "select",
      "main" => false,
      "changes" => ["lib/producer.rb"],
      "test_changes" => [],
      "deleted_tests" => [],
      "jobs" => {
        "backend" => {
          "inventory" => inventory,
          "environment" => "core",
          "mapping_changes" => [],
          "verified_sources" => ["lib/producer.rb"],
          "changed_methods" =>
            (
              snapshot.fetch("tests").values.flatten +
                snapshot.fetch("source_dependencies").values.flatten +
                snapshot.fetch("initialization_sources")
            ).grep(%r{\A__method__/lib/producer\.rb/}),
          "mapping" => mapping,
        },
      },
    }
    TestSelection::Planner.new(input).plan.fetch("files")
  end

  shared_examples "a cached fixture dependency" do |description:, setup:, value:, expected: nil, compact: nil, external: nil|
    it "connects #{description} to later cache readers" do
      Dir.mktmpdir("context-fixture-") do |root|
        FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor", "#{root}/spec/support"])
        File.write(
          "#{root}/vendor/cache.rb",
          "module ContextFixtureCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
        )
        File.write(
          "#{root}/lib/producer.rb",
          "module ContextFixtureProducer; def self.value; :original; end; end",
        )
        File.write(
          "#{root}/vendor/cleanup.rb",
          "class ContextFixtureCleanup; def finish(force = false); end; end",
        )
        File.write(
          "#{root}/lib/lifecycle.rb",
          "module ContextFixtureLifecycle; class << self; attr_reader :cleanup; def setup; @cleanup = ContextFixtureCleanup.new; end; end; end",
        )
        File.write("#{root}/spec/support/lifecycle.rb", <<~SUPPORT)
          RSpec.configure do |config|
            config.around do |example|
              example.run
              ContextFixtureLifecycle.cleanup.finish
            end
          end
        SUPPORT
        File.write("#{root}/spec/writer_spec.rb", <<~SPEC)
          RSpec.describe 'Context fixture writer' do
            #{setup}
            context 'nested group' do
              it('stores the fixture') { ContextFixtureCache.write(#{value}) }
            end
          end
        SPEC
        if compact
          writer = "#{root}/spec/writer_spec.rb"
          File.write(writer, File.read(writer).gsub("\n", "; "))
        end
        if external
          File.write("#{root}/vendor/shared_examples.rb", <<~EXAMPLES)
            RSpec.shared_examples 'External writer' do
              it('stores a value') { ContextFixtureCache.write(ContextFixtureProducer.value) }
            end
          EXAMPLES
          File.write(
            "#{root}/spec/writer_spec.rb",
            "RSpec.describe('External host') { include_examples 'External writer' }",
          )
        end
        File.write(
          "#{root}/spec/reader_spec.rb",
          "RSpec.describe('Reader') { it('reads the cache') { expect(ContextFixtureCache.value).to eq(:original) } }",
        )
        File.write(
          "#{root}/spec/unrelated_spec.rb",
          "RSpec.describe('Unrelated') { it('passes') { expect(true).to eq(true) } }",
        )
        output = "#{root}/mapping.json"
        bootstrap =
          if setup.start_with?("fab!", "shared_fixture")
            "require 'test_prof/recipes/rspec/let_it_be'; TestProf::BeforeAll.adapter = TestProf::BeforeAll::NoopAdapter; TestProf::LetItBe.configure { |config| config.alias_to :fab!; config.alias_to :shared_fixture }"
          end
        program = <<~RUBY
          require 'json'
          require 'rspec/core'
          #{bootstrap}
          #{external ? "load #{"#{root}/vendor/shared_examples.rb".inspect}" : ""}
          require #{File.expand_path("../../script/ci/ruby_dependencies", __dir__).inspect}
          load #{"#{root}/vendor/cache.rb".inspect}
          load #{"#{root}/vendor/cleanup.rb".inspect}
          collector = TestSelection::RubyDependencies.new(root: #{root.inspect})
          collector.start
          load #{"#{root}/lib/producer.rb".inspect}
          load #{"#{root}/lib/lifecycle.rb".inspect}
          ContextFixtureLifecycle.setup
          load #{"#{root}/spec/support/lifecycle.rb".inspect}
          RSpec.configure do |config|
            config.prepend_before(:context) do
              collector.begin_test(self.class.metadata.fetch(:rerun_file_path).delete_prefix(#{"#{root}/".inspect})) unless self.class.metadata[:parent_example_group]
            end
            config.append_after(:context) do
              collector.finish_test unless self.class.metadata[:parent_example_group]
            end
          end
          status = RSpec::Core::Runner.run(['--options', '/dev/null', '--order', 'defined', #{"#{root}/spec/writer_spec.rb".inspect}, #{"#{root}/spec/reader_spec.rb".inspect}, #{"#{root}/spec/unrelated_spec.rb".inspect}])
          collector.stop
          File.write(#{output.inspect}, JSON.generate(collector.snapshot))
          exit(status)
        RUBY

        log, status = Open3.capture2e(isolated_rspec_environment, RbConfig.ruby, "-e", program)

        expect(status.success?).to eq(true), log
        expect(selected_for_producer(JSON.parse(File.read(output)))).to eq(
          expected || %w[spec/reader_spec.rb spec/writer_spec.rb],
        )
      end
    end
  end

  it_behaves_like "a cached fixture dependency",
                  description: "a context fixture copied into a nested RSpec group",
                  setup: "before(:context) { @fixture_value = ContextFixtureProducer.value }",
                  value: "@fixture_value"
  it_behaves_like "a cached fixture dependency",
                  description: "a memoized scalar fixture",
                  setup: "let(:fixture_value) { ContextFixtureProducer.value }",
                  value: "fixture_value"
  it_behaves_like "a cached fixture dependency",
                  description: "a context fixture assigned by a helper method",
                  setup:
                    "def prepare_fixture; @fixture_value = ContextFixtureProducer.value; end; before(:context) { prepare_fixture }",
                  value: "@fixture_value"
  it_behaves_like "a cached fixture dependency",
                  description: "a compact memoized fixture declaration",
                  setup: "let(:fixture_value) { ContextFixtureProducer.value }",
                  value: "fixture_value",
                  expected: nil,
                  compact: true
  it_behaves_like "a cached fixture dependency",
                  description: "an example body outside the mapped spec sources",
                  setup: "",
                  value: "unused",
                  expected: %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb],
                  compact: false,
                  external: true
  it_behaves_like "a cached fixture dependency",
                  description: "an eager fixture with framework storage",
                  setup: "let!(:fixture_value) { ContextFixtureProducer.value }",
                  value: "fixture_value",
                  expected: %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb]
  it_behaves_like "a cached fixture dependency",
                  description: "an aliased shared fixture",
                  setup: "shared_fixture(:fixture_value) { ContextFixtureProducer.value }",
                  value: "fixture_value",
                  expected: %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb]
  it_behaves_like "a cached fixture dependency",
                  description: "a shared fixture populated through reflection",
                  setup: "fab!(:fixture_value) { ContextFixtureProducer.value }",
                  value: "fixture_value",
                  expected: %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb]

  it "protects background calls that execute while another spec file is active" do
    Dir.mktmpdir("background-dependency-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      File.write(
        "#{root}/lib/producer.rb",
        "module BackgroundProbeProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/cache.rb",
        "module BackgroundProbeCache; class << self; attr_accessor :value; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module BackgroundProbeWriter; def self.populate; BackgroundProbeCache.value = BackgroundProbeProducer.value; end; end",
      )
      gate = Queue.new
      collector = described_class.new(root: root)
      collector.start
      %w[producer cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
      collector.begin_test("spec/writer_spec.rb")
      thread =
        Thread.new do
          gate.pop
          BackgroundProbeWriter.populate
        end
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      gate << true
      thread.join
      expect(BackgroundProbeCache.value).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      gate << true if gate
      thread&.join
      %i[BackgroundProbeProducer BackgroundProbeCache BackgroundProbeWriter].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "distinguishes an unexecuted external write from an executed write of the same value" do
    Dir.mktmpdir("external-conditional-write-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      File.write("#{root}/vendor/cache.rb", <<~RUBY)
        module ConditionalExternalCache
          @live = :original
          @dead = :constant
          def self.write(value)
            if false
              @dead = value
            end
            @live = value
          end
          def self.live
            @live
          end
          def self.dead
            @dead
          end
        end
      RUBY
      File.write(
        "#{root}/lib/producer.rb",
        "module ConditionalExternalProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module ConditionalExternalWriter; def self.populate; ConditionalExternalCache.write(ConditionalExternalProducer.value); end; end",
      )
      load "#{root}/vendor/cache.rb"
      collector = described_class.new(root: root)
      collector.start
      %w[producer writer].each { |name| load "#{root}/lib/#{name}.rb" }
      collector.begin_test("spec/writer_spec.rb")
      ConditionalExternalWriter.populate
      collector.finish_test
      collector.begin_test("spec/live_reader_spec.rb")
      expect(ConditionalExternalCache.live).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/dead_reader_spec.rb")
      expect(ConditionalExternalCache.dead).to eq(:constant)
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/live_reader_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      %i[
        ConditionalExternalCache
        ConditionalExternalProducer
        ConditionalExternalWriter
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  it "records persistent writes and readers inside an external cache API" do
    Dir.mktmpdir("external-cache-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      File.write(
        "#{root}/vendor/cache.rb",
        "module ExternalCacheProbe; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module ExternalCacheProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module ExternalCacheWriter; def self.populate; ExternalCacheProbe.write(ExternalCacheProducer.value); end; end",
      )
      File.write(
        "#{root}/lib/boot.rb",
        "module ExternalCacheBoot; VALUE = ExternalCacheProbe.value; end",
      )
      load "#{root}/vendor/cache.rb"
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/writer.rb"
      load "#{root}/lib/boot.rb"
      collector.begin_test("spec/writer_spec.rb")
      ExternalCacheWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(ExternalCacheProbe.value).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      %i[
        ExternalCacheProbe
        ExternalCacheProducer
        ExternalCacheWriter
        ExternalCacheBoot
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  it "keeps ordinary autoloading separate from an explicit delayed require" do
    Dir.mktmpdir("autoload-cache-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      producer = "#{root}/lib/producer.rb"
      File.write(producer, "module AutoloadCacheProducer; def self.value; :original; end; end")
      File.write(
        "#{root}/lib/cache.rb",
        "module AutoloadCacheProbe; class << self; attr_reader :values; def setup; @values = {}; end; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module AutoloadCacheWriter; def self.populate; AutoloadCacheProbe.values[:key] = AutoloadCacheProducer.value; end; end",
      )
      Object.autoload(:AutoloadCacheProducer, producer)
      collector = described_class.new(root: root)
      collector.start
      %w[cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
      AutoloadCacheProbe.setup
      collector.begin_test("spec/writer_spec.rb")
      AutoloadCacheWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(AutoloadCacheProbe.values[:key]).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      $LOADED_FEATURES.delete(producer)
      %i[AutoloadCacheProbe AutoloadCacheProducer AutoloadCacheWriter].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "keeps a producer separate from an unrelated cached configuration read" do
    Dir.mktmpdir("unrelated-opaque-cache-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      File.write(
        "#{root}/vendor/configuration.rb",
        "class UnrelatedOpaqueConfiguration; attr_reader :enabled; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module UnrelatedOpaqueProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/cache.rb",
        "module UnrelatedOpaqueCache; class << self; attr_reader :configuration; def setup; @configuration = UnrelatedOpaqueConfiguration.new; end; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module UnrelatedOpaqueWriter; def self.populate; UnrelatedOpaqueProducer.value; UnrelatedOpaqueCache.configuration.enabled; end; end",
      )
      load "#{root}/vendor/configuration.rb"
      collector = described_class.new(root: root)
      collector.start
      %w[producer cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
      UnrelatedOpaqueCache.setup
      collector.begin_test("spec/writer_spec.rb")
      UnrelatedOpaqueWriter.populate
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(["spec/writer_spec.rb"])
    ensure
      collector&.stop
      %i[
        UnrelatedOpaqueConfiguration
        UnrelatedOpaqueCache
        UnrelatedOpaqueProducer
        UnrelatedOpaqueWriter
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  it "retains a native cache read nested inside an opaque cached object" do
    Dir.mktmpdir("nested-opaque-cache-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      File.write(
        "#{root}/vendor/reader.rb",
        "class NestedOpaqueReader; def value; NestedOpaqueCache.inner; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module NestedOpaqueProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/cache.rb",
        "module NestedOpaqueCache; class << self; attr_accessor :inner; attr_reader :outer; def setup; @outer = NestedOpaqueReader.new; end; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module NestedOpaqueWriter; def self.populate; NestedOpaqueCache.inner = NestedOpaqueProducer.value; end; end",
      )
      load "#{root}/vendor/reader.rb"
      collector = described_class.new(root: root)
      collector.start
      %w[producer cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
      NestedOpaqueCache.setup
      collector.begin_test("spec/writer_spec.rb")
      NestedOpaqueWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(NestedOpaqueCache.outer.value).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      %i[
        NestedOpaqueReader
        NestedOpaqueCache
        NestedOpaqueProducer
        NestedOpaqueWriter
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  it "records external cache dependencies when collection starts inside require" do
    Dir.mktmpdir("collector-activation-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor", "#{root}/script"])
      activation = "#{root}/script/activate.rb"
      File.write(
        "#{root}/vendor/cache.rb",
        "module ImportDepthCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module ImportDepthProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module ImportDepthWriter; def self.populate; ImportDepthCache.write(ImportDepthProducer.value); end; end",
      )
      File.write(
        activation,
        "ImportDepthCollector = TestSelection::RubyDependencies.new(root: #{root.inspect}); ImportDepthCollector.start",
      )
      %w[vendor/cache lib/producer lib/writer].each { |path| load "#{root}/#{path}.rb" }
      require activation
      collector = ImportDepthCollector
      collector.begin_test("spec/writer_spec.rb")
      ImportDepthWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(ImportDepthCache.value).to eq(:original)
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      $LOADED_FEATURES.delete(activation)
      %i[ImportDepthCache ImportDepthProducer ImportDepthWriter ImportDepthCollector].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "includes cache readers when spec execution order can change" do
    Dir.mktmpdir("external-cache-order-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor", "#{root}/spec"])
      File.write(
        "#{root}/vendor/cache.rb",
        "module OrderedExternalCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module OrderedExternalProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module OrderedExternalWriter; def self.populate; OrderedExternalCache.write(OrderedExternalProducer.value); end; end",
      )
      File.write(
        "#{root}/spec/earlier_spec.rb",
        "raise 'Earlier value changed' unless OrderedExternalCache.value.nil?",
      )
      File.write(
        "#{root}/spec/later_spec.rb",
        "raise 'Later value missing' unless OrderedExternalCache.value == :original",
      )
      load "#{root}/vendor/cache.rb"
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/writer.rb"
      collector.begin_test("spec/earlier_spec.rb")
      load "#{root}/spec/earlier_spec.rb"
      collector.finish_test
      collector.begin_test("spec/writer_spec.rb")
      OrderedExternalWriter.populate
      collector.finish_test
      collector.begin_test("spec/later_spec.rb")
      load "#{root}/spec/later_spec.rb"
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/earlier_spec.rb spec/later_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      %i[OrderedExternalCache OrderedExternalProducer OrderedExternalWriter].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "broadens for a producer used by an external library during a delayed require" do
    Dir.mktmpdir("external-cache-require-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      payload = "#{root}/vendor/populate.rb"
      File.write(
        "#{root}/vendor/cache.rb",
        "module RequiredExternalCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module RequiredExternalProducer; def self.value; :original; end; end",
      )
      File.write(payload, "RequiredExternalCache.write(RequiredExternalProducer.value)")
      File.write(
        "#{root}/lib/writer.rb",
        "module RequiredExternalWriter; def self.populate; require #{payload.inspect}; end; end",
      )
      load "#{root}/vendor/cache.rb"
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/writer.rb"
      collector.begin_test("spec/writer_spec.rb")
      RequiredExternalWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(RequiredExternalCache.value).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      $LOADED_FEATURES.delete(payload)
      %i[RequiredExternalCache RequiredExternalProducer RequiredExternalWriter].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "retains a cached producer read by later library initialization" do
    Dir.mktmpdir("cached-initialization-") do |root|
      FileUtils.mkdir_p(["#{root}/lib", "#{root}/vendor"])
      payload = "#{root}/lib/snapshot.rb"
      File.write(
        "#{root}/vendor/cache.rb",
        "module LoadedExternalCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      File.write(
        "#{root}/lib/producer.rb",
        "module LoadedExternalProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/writer.rb",
        "module LoadedExternalWriter; def self.populate; LoadedExternalCache.write(LoadedExternalProducer.value); end; end",
      )
      File.write(payload, "module LoadedExternalSnapshot; VALUE = LoadedExternalCache.value; end")
      File.write(
        "#{root}/lib/loader.rb",
        "module LoadedExternalLoader; def self.prepare; require #{payload.inspect}; end; end",
      )
      load "#{root}/vendor/cache.rb"
      collector = described_class.new(root: root)
      collector.start
      %w[producer writer loader].each { |name| load "#{root}/lib/#{name}.rb" }
      collector.begin_test("spec/writer_spec.rb")
      LoadedExternalWriter.populate
      collector.finish_test
      collector.begin_test("spec/loader_spec.rb")
      LoadedExternalLoader.prepare
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(LoadedExternalSnapshot::VALUE).to eq(:original)
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(
        %w[spec/loader_spec.rb spec/reader_spec.rb spec/unrelated_spec.rb spec/writer_spec.rb],
      )
    ensure
      collector&.stop
      $LOADED_FEATURES.delete(payload)
      %i[
        LoadedExternalCache
        LoadedExternalProducer
        LoadedExternalWriter
        LoadedExternalSnapshot
        LoadedExternalLoader
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  it "marks producers consumed while a class initializes a cached constant" do
    Dir.mktmpdir("initialization-dependencies-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      File.write(
        "#{root}/lib/producer.rb",
        "module InitializationProbeProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/reader.rb",
        "module InitializationProbeReader; VALUE = InitializationProbeProducer.value; end",
      )
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/reader.rb"
      collector.begin_test("spec/constant_consumer_spec.rb")
      expect(InitializationProbeReader::VALUE).to eq(:original)
      collector.finish_test
      collector.stop

      result = collector.snapshot

      expect(result.fetch("initialization_sources")).to include("__method__/lib/producer.rb/0")
      path = "#{root}/lib/producer.rb"
      description =
        RspecSourceStructure.describe(
          path,
          boot_lines: result.fetch("initialization_lines").fetch("lib/producer.rb"),
        )
      File.write(path, File.read(path).sub(":original", ":changed"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    ensure
      collector&.stop
      Object.send(:remove_const, :InitializationProbeReader) if defined?(InitializationProbeReader)
      if defined?(InitializationProbeProducer)
        Object.send(:remove_const, :InitializationProbeProducer)
      end
    end
  end

  shared_examples "a dynamically initialized producer" do |reader_source:|
    it "marks producers used by dynamic and top level initialization: #{reader_source}" do
      Dir.mktmpdir("dynamic-initialization-") do |root|
        FileUtils.mkdir_p("#{root}/lib")
        File.write(
          "#{root}/lib/producer.rb",
          "module InitializationDynamicProbeProducer; def self.value; :original; end; end",
        )
        File.write("#{root}/lib/reader.rb", reader_source)
        collector = described_class.new(root: root)
        collector.start
        load "#{root}/lib/producer.rb"
        load "#{root}/lib/reader.rb"
        collector.stop

        snapshot = collector.snapshot
        expect(
          snapshot
            .fetch("initialization_sources")
            .any? do |path|
              path.start_with?("__method__/lib/producer.rb/", "__method__/lib/reader.rb/")
            end,
        ).to eq(true)
      ensure
        collector&.stop
        if defined?(InitializationDynamicProbeReader)
          Object.send(:remove_const, :InitializationDynamicProbeReader)
        end
        if defined?(InitializationDynamicProbeProducer)
          Object.send(:remove_const, :InitializationDynamicProbeProducer)
        end
        if Object.private_method_defined?(:initialization_probe_factory)
          Object.send(:remove_method, :initialization_probe_factory)
        end
      end
    end
  end

  it_behaves_like "a dynamically initialized producer",
                  reader_source:
                    "InitializationDynamicProbeReader = Class.new { const_set(:VALUE, InitializationDynamicProbeProducer.value) }"
  it_behaves_like "a dynamically initialized producer",
                  reader_source:
                    "InitializationDynamicProbeReader = InitializationDynamicProbeProducer.value"
  it_behaves_like "a dynamically initialized producer",
                  reader_source:
                    "def initialization_probe_factory; Class.new { const_set(:VALUE, InitializationDynamicProbeProducer.value) }; end; InitializationDynamicProbeReader = initialization_probe_factory"

  it "marks a native cached accessor used by top level constant initialization" do
    Dir.mktmpdir("native-initialization-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      File.write(
        "#{root}/lib/producer.rb",
        "module InitializationNativeProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/cache.rb",
        "module InitializationNativeCache; class << self; attr_reader :value; def populate; @value = InitializationNativeProducer.value; end; end; end",
      )
      File.write(
        "#{root}/lib/reader.rb",
        "InitializationNativeReader = InitializationNativeCache.value",
      )
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/cache.rb"
      InitializationNativeCache.populate
      load "#{root}/lib/reader.rb"
      collector.begin_test("spec/consumer_spec.rb")
      expect(InitializationNativeReader).to eq(:original)
      collector.finish_test
      collector.stop

      snapshot = collector.snapshot
      expect(selected_for_producer(snapshot)).to eq(["spec/consumer_spec.rb"])
      expect(snapshot.fetch("initialization_sources")).to include(
        "__method__/lib/cache.rb/native/value",
      )
    ensure
      collector&.stop
      %i[
        InitializationNativeReader
        InitializationNativeCache
        InitializationNativeProducer
      ].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    end
  end

  shared_examples "a cached native accessor" do |accessor:|
    it "records cached native accessor readers and their delegated producer dependency: #{accessor}" do
      Dir.mktmpdir("ruby-dependencies-") do |root|
        FileUtils.mkdir_p("#{root}/lib")
        producer = "#{root}/lib/producer.rb"
        reader = "#{root}/lib/reader.rb"
        File.write(producer, "module DependencyProbeProducer; def self.value; :original; end; end")
        File.write(
          reader,
          "class DependencyProbeReader; class << self; #{accessor}; def populate; @value = DependencyProbeProducer.value; @original_value = @value; end; end; end",
        )
        collector = described_class.new(root: root)
        collector.start
        load producer
        load reader
        collector.begin_test("spec/populate_spec.rb")
        DependencyProbeReader.populate
        collector.finish_test
        collector.begin_test("spec/consumer_spec.rb")
        expect(DependencyProbeReader.value).to eq(:original)
        collector.finish_test
        collector.stop

        result = collector.snapshot

        expect(selected_for_producer(result)).to eq(%w[spec/consumer_spec.rb spec/populate_spec.rb])
      ensure
        collector&.stop
        Object.send(:remove_const, :DependencyProbeReader) if defined?(DependencyProbeReader)
        Object.send(:remove_const, :DependencyProbeProducer) if defined?(DependencyProbeProducer)
      end
    end
  end

  it_behaves_like "a cached native accessor", accessor: "attr_reader :value"
  it_behaves_like "a cached native accessor",
                  accessor:
                    "attr_reader :original_value; alias_method :value, :original_value; remove_method :original_value"

  shared_examples "a separate cache writer" do |cache_definition:, write:, read:, cache_path: nil|
    cache_path ||= "lib/cache.rb"
    it "connects a separate cache writer to later readers: #{write} (#{cache_path})" do
      Dir.mktmpdir("separate-cache-writer-") do |root|
        FileUtils.mkdir_p("#{root}/lib")
        File.write(
          "#{root}/lib/producer.rb",
          "module SeparateCacheProducer; def self.value; :original; end; end",
        )
        FileUtils.mkdir_p(File.dirname("#{root}/#{cache_path}"))
        File.write(
          "#{root}/#{cache_path}",
          "module SeparateCache; class << self; #{cache_definition}; end; end",
        )
        File.write(
          "#{root}/lib/writer.rb",
          "module SeparateCacheWriter; def self.populate; #{write}; end; end",
        )
        collector = described_class.new(root: root)
        collector.start
        ["lib/producer.rb", cache_path, "lib/writer.rb"].each { |path| load "#{root}/#{path}" }
        SeparateCache.setup if SeparateCache.respond_to?(:setup)
        collector.begin_test("spec/writer_spec.rb")
        SeparateCacheWriter.populate
        collector.finish_test
        collector.begin_test("spec/reader_spec.rb")
        expect(read.call).to eq(:original)
        collector.finish_test
        collector.stop
        snapshot = collector.snapshot
        tests = snapshot.fetch("tests")
        inventory = tests.keys.sort
        input = {
          "revision" => "b" * 40,
          "mode" => "select",
          "main" => false,
          "changes" => ["lib/producer.rb"],
          "test_changes" => [],
          "deleted_tests" => [],
          "jobs" => {
            "backend" => {
              "inventory" => inventory,
              "environment" => "core",
              "mapping_changes" => [],
              "verified_sources" => ["lib/producer.rb"],
              "changed_methods" =>
                (
                  snapshot.fetch("tests").values.flatten +
                    snapshot.fetch("source_dependencies").values.flatten +
                    snapshot.fetch("initialization_sources")
                ).grep(%r{\A__method__/lib/producer\.rb/}),
              "mapping" =>
                snapshot.merge(
                  "version" => 2,
                  "revision" => "a" * 40,
                  "complete" => true,
                  "environment" => "core",
                  "sources" => %w[lib/producer.rb lib/cache.rb lib/writer.rb],
                  "shared_files" => [],
                ),
            },
          },
        }

        result = TestSelection::Planner.new(input).plan

        expect(result.fetch("files")).to eq(inventory)
      ensure
        collector&.stop
        %i[SeparateCacheWriter SeparateCache SeparateCacheProducer].each do |name|
          Object.send(:remove_const, name) if Object.const_defined?(name)
        end
      end
    end
  end

  it_behaves_like "a separate cache writer",
                  cache_definition: "attr_accessor :value",
                  write: "SeparateCache.value = SeparateCacheProducer.value",
                  read: -> { SeparateCache.value },
                  cache_path: "plugins/cache_probe/plugin.rb"
  it_behaves_like "a separate cache writer",
                  cache_definition: "attr_reader :value",
                  write:
                    "SeparateCache.instance_variable_set(:@value, SeparateCacheProducer.value)",
                  read: -> { SeparateCache.value }
  it_behaves_like "a separate cache writer",
                  cache_definition: "attr_accessor :value",
                  write: "SeparateCache.value = SeparateCacheProducer.value",
                  read: -> { SeparateCache.value }
  it_behaves_like "a separate cache writer",
                  cache_definition:
                    "attr_accessor :value; alias_method :store, :value=; remove_method :value=",
                  write: "SeparateCache.store(SeparateCacheProducer.value)",
                  read: -> { SeparateCache.value }
  it_behaves_like "a separate cache writer",
                  cache_definition: "attr_reader :value; def store(value); @value = value; end",
                  write: "SeparateCache.store(SeparateCacheProducer.value)",
                  read: -> { SeparateCache.value }
  it_behaves_like "a separate cache writer",
                  cache_definition: "attr_reader :values; def setup; @values = {}; end",
                  write: "SeparateCache.values[:key] = SeparateCacheProducer.value",
                  read: -> { SeparateCache.values[:key] }

  it "keeps unrelated fields separate when both contain the same frozen empty array" do
    Dir.mktmpdir("shared-empty-container-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      File.write(
        "#{root}/lib/producer.rb",
        "module EmptyArrayProducer; def self.value; :original; end; end",
      )
      File.write("#{root}/lib/cache.rb", <<~RUBY)
        module EmptyArrayCache
          EMPTY = [].freeze
          class << self
            attr_accessor :first, :second
            def populate
              self.first = EMPTY
              self.second = EMPTY
              EmptyArrayProducer.value
              first
            end
          end
        end
      RUBY
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/cache.rb"
      collector.begin_test("spec/producer_spec.rb")
      EmptyArrayCache.populate
      collector.finish_test
      collector.begin_test("spec/unrelated_spec.rb")
      expect(EmptyArrayCache.second).to eq([])
      collector.finish_test
      collector.stop

      expect(selected_for_producer(collector.snapshot)).to eq(["spec/producer_spec.rb"])
    ensure
      collector&.stop
      %i[EmptyArrayCache EmptyArrayProducer].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  shared_examples "a native cache mutation" do |definition:, write:, read:, extra: nil|
    it "retains a cached consumer after #{write}" do
      Dir.mktmpdir("native-mutation-") do |root|
        FileUtils.mkdir_p("#{root}/lib")
        File.write(
          "#{root}/lib/producer.rb",
          "module MutationProducer; def self.value; :original; end; end",
        )
        File.write(
          "#{root}/lib/cache.rb",
          "module MutationCache; class << self; #{definition}; end; end",
        )
        File.write(
          "#{root}/lib/writer.rb",
          "module MutationWriter; def self.populate; #{write}; end; #{extra}; end",
        )
        collector = described_class.new(root: root)
        collector.start
        %w[producer cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
        MutationCache.setup
        collector.begin_test("spec/writer_spec.rb")
        MutationWriter.populate
        collector.finish_test
        collector.begin_test("spec/reader_spec.rb")
        expect(read.call.to_s).to eq("original")
        collector.finish_test
        collector.stop

        expect(selected_for_producer(collector.snapshot)).to eq(
          %w[spec/reader_spec.rb spec/writer_spec.rb],
        )
      ensure
        collector&.stop
        Thread.current[:selection_mutation_probe] = nil
        %i[MutationWriter MutationCache MutationProducer].each do |name|
          Object.send(:remove_const, name) if Object.const_defined?(name)
        end
      end
    end
  end

  it_behaves_like "a native cache mutation",
                  definition: "attr_accessor :value; def setup; @value = +\"\"; end",
                  write: "MutationCache.value.insert(0, MutationProducer.value.to_s)",
                  read: -> { MutationCache.value }
  it_behaves_like "a native cache mutation",
                  definition: "attr_accessor :café; def setup; end",
                  write: "MutationCache.café = MutationProducer.value",
                  read: -> { MutationCache.café }
  it_behaves_like "a native cache mutation",
                  definition:
                    "attr_accessor :value; def setup; @value = {keep: :original, drop: :other}; end",
                  write:
                    "MutationCache.value.keep_if { |_, value| value == MutationProducer.value }",
                  read: -> { MutationCache.value.values.first }
  it_behaves_like "a native cache mutation",
                  definition: "attr_accessor :value; def setup; @value = Set.new; end",
                  write: "MutationCache.value.merge([MutationProducer.value])",
                  read: -> { MutationCache.value.first }
  it_behaves_like "a native cache mutation",
                  definition: "def setup; end",
                  write: "Thread.current[:selection_mutation_probe] = MutationProducer.value",
                  read: -> { Thread.current[:selection_mutation_probe] }
  it_behaves_like "a native cache mutation",
                  definition:
                    "attr_accessor :value; def setup; @value = URI.parse(\"https://initial.invalid\"); end",
                  write: "MutationWriter.apply(MutationProducer.value.to_s)",
                  read: -> { MutationCache.value.host },
                  extra: "def self.apply(value); MutationCache.value.host = value; end"

  it "keeps direct spec write dependencies after an intervening cache read" do
    Dir.mktmpdir("direct-cache-write-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      FileUtils.mkdir_p("#{root}/spec")
      File.write(
        "#{root}/lib/producer.rb",
        "module DirectCacheProducer; def self.value; :original; end; end",
      )
      File.write(
        "#{root}/lib/cache.rb",
        "module DirectCache; class << self; attr_accessor :value; end; end",
      )
      File.write(
        "#{root}/spec/writer_spec.rb",
        "proc { value = DirectCacheProducer.value; DirectCache.value; DirectCache.value = value }.call",
      )
      collector = described_class.new(root: root)
      collector.start
      load "#{root}/lib/producer.rb"
      load "#{root}/lib/cache.rb"
      collector.begin_test("spec/writer_spec.rb")
      load "#{root}/spec/writer_spec.rb"
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(DirectCache.value).to eq(:original)
      collector.finish_test
      collector.stop

      snapshot = collector.snapshot

      expect(selected_for_producer(snapshot)).to eq(%w[spec/reader_spec.rb spec/writer_spec.rb])
    ensure
      collector&.stop
      %i[DirectCache DirectCacheProducer].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "broadens when a producer mutates a shared string constant" do
    Dir.mktmpdir("string-cache-write-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      File.write(
        "#{root}/lib/producer.rb",
        'module StringCacheProducer; def self.value; "original"; end; end',
      )
      File.write("#{root}/lib/cache.rb", 'module StringCache; VALUE = +""; end')
      File.write(
        "#{root}/lib/writer.rb",
        "module StringCacheWriter; def self.populate; StringCache::VALUE.replace(StringCacheProducer.value); end; end",
      )
      collector = described_class.new(root: root)
      collector.start
      %w[producer cache writer].each { |name| load "#{root}/lib/#{name}.rb" }
      collector.begin_test("spec/writer_spec.rb")
      StringCacheWriter.populate
      collector.finish_test
      collector.begin_test("spec/reader_spec.rb")
      expect(StringCache::VALUE).to eq("original")
      collector.finish_test
      collector.stop

      snapshot = collector.snapshot

      expect(selected_for_producer(snapshot)).to eq(%w[spec/reader_spec.rb spec/writer_spec.rb])
    ensure
      collector&.stop
      %i[StringCacheWriter StringCache StringCacheProducer].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end
  end

  it "records cached readers defined by Ruby blocks and their producer dependency" do
    Dir.mktmpdir("ruby-dependencies-") do |root|
      FileUtils.mkdir_p("#{root}/lib")
      producer = "#{root}/lib/producer.rb"
      reader = "#{root}/lib/reader.rb"
      File.write(
        producer,
        "module DependencyBlockProbeProducer; def self.value; :original; end; end",
      )
      File.write(
        reader,
        "class DependencyBlockProbeReader; class << self; define_method(:value) { @value }; def populate; @value = DependencyBlockProbeProducer.value; end; end; end",
      )
      collector = described_class.new(root: root)
      collector.start
      load producer
      load reader
      collector.begin_test("spec/populate_spec.rb")
      DependencyBlockProbeReader.populate
      collector.finish_test
      collector.begin_test("spec/consumer_spec.rb")
      expect(DependencyBlockProbeReader.value).to eq(:original)
      collector.finish_test
      collector.stop

      result = collector.snapshot

      expect(selected_for_producer(result)).to eq(%w[spec/consumer_spec.rb spec/populate_spec.rb])
    ensure
      collector&.stop
      if defined?(DependencyBlockProbeReader)
        Object.send(:remove_const, :DependencyBlockProbeReader)
      end
      if defined?(DependencyBlockProbeProducer)
        Object.send(:remove_const, :DependencyBlockProbeProducer)
      end
    end
  end
end

RSpec.describe TestExecution do
  include RSpecSubprocessEnvironment
  it "observes an exec wrapper while isolating Ruby children before specs load" do
    Dir.mktmpdir("execution-", "tmp") do |directory|
      file = "#{directory}/child_spec.rb"
      wrapper = "#{directory}/wrapper.rb"
      startup_check = "#{directory}/plain_start.rb"
      File.write(startup_check, 'abort "Launcher must start without Bundler" if defined?(Bundler)')
      File.write(wrapper, 'exec "bundle", "exec", "rspec", *ARGV')
      File.write(file, <<~RUBY)
        require "open3"
        require "rbconfig"
        probe = <<~CHILD
          abort "RSpec leaked into a child" if defined?(RSpec)
          options = ENV.fetch("RUBYOPT", "")
          abort "Original option missing" unless options.split.include?("-W0")
          abort "Observer leaked into a child" if options.include?("rspec_execution")
        CHILD
        output, error, status = Open3.capture3(RbConfig.ruby, "-e", probe)
        Bundler.with_unbundled_env do
          unbundled_output, unbundled_error, unbundled_status =
            Open3.capture3(RbConfig.ruby, "-e", probe)
          raise unbundled_error unless unbundled_status.success?
        end
        RSpec.describe "Ruby child environment" do
          it "keeps the original options without the observer" do
            expect(status.success?).to eq(true), error
            expect(ENV.key?("TEST_SELECTION_ORIGINAL_RUBYOPT")).to eq(false)
          end
        end
      RUBY
      revision = "c" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "backend" => [file],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => [file],
            "environment" => "core",
            "runner" => "rspec",
            "command" => [RbConfig.ruby, wrapper, "--options", "/dev/null"],
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      output, error, status =
        Open3.capture3(
          isolated_rspec_environment.merge(
            ENV.keys.grep(/\ABUNDLER_ORIG_/).to_h { |key| [key, nil] },
            "GITHUB_SHA" => revision,
            "RUBYOPT" => "-W0",
            "BUNDLER_SETUP" => nil,
            "BUNDLE_BIN_PATH" => nil,
            "BUNDLER_VERSION" => nil,
            "RUBYLIB" => nil,
          ),
          RbConfig.ruby,
          "-r",
          File.expand_path(startup_check),
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "backend",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(true), "#{output}\n#{error}"
      expect(report.slice("loaded", "examples", "failures", "exact")).to eq(
        "loaded" => [file],
        "examples" => 1,
        "failures" => [],
        "exact" => true,
      )
    end
  end

  it "records actual RSpec outcomes without fabricated examples" do
    Dir.mktmpdir("execution-", "tmp") do |directory|
      file = "#{directory}/added_spec.rb"
      File.write(file, <<~RUBY)
        RSpec.describe("Selected file") do
          it("passes") do
            fabricated = RSpec::Core::Example.describe.example("Fabricated failure")
            fabricated.execution_result.status = :failed
            expect(true).to eq(true)
          end
        end
        RSpec.describe("Around failure") do
          around(:example) { |_example| raise "Actual around hook failure" }
          it("fails before its body") {}
        end
        RSpec.describe("Context failure") do
          before(:context) { raise "Actual context hook failure" }
          it("fails before its body") {}
        end
      RUBY
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "backend" => [file],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "seed" => 1234,
        "jobs" => {
          "backend" => {
            "inventory" => [file],
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge("GITHUB_SHA" => revision),
          RbConfig.ruby,
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "backend",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(false)
      expect(report.slice("loaded", "examples", "failures", "exact", "unreported_failure")).to eq(
        "loaded" => [file],
        "examples" => 3,
        "failures" => ["./#{file}[2:1]", "./#{file}[3:1]"],
        "exact" => true,
        "unreported_failure" => false,
      )
    end
  end

  it "preserves a job's defined example order when assigning its seed" do
    Dir.mktmpdir("execution-order-", "tmp") do |directory|
      file = "#{directory}/migration_spec.rb"
      sequence = File.expand_path("#{directory}/sequence")
      File.write(file, <<~RUBY)
        RSpec.configure do |config|
          config.before(:example) do |example|
            File.open(#{sequence.dump}, "a") { |output| output.puts(example.description) }
          end
        end
        RSpec.describe "Migration declaration order" do
          it("first") {}
          it("second") {}
          it("third") {}
        end
      RUBY
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "migration" => [file],
        },
        "environments" => {
          "migration" => "plain",
        },
      }
      job = {
        "inventory" => [file],
        "environment" => "plain",
        "runner" => "rspec",
        "command" => %w[bundle exec rspec --options /dev/null],
        "order" => "defined",
      }
      catalog = { "revision" => revision, "seed" => 2, "jobs" => { "migration" => job } }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      output, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge("GITHUB_SHA" => revision),
          RbConfig.ruby,
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "migration",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(true)
      expect(output).not_to include("Randomized with seed")
      expect(report.slice("loaded", "examples", "exact")).to eq(
        "loaded" => [file],
        "examples" => 3,
        "exact" => true,
      )
      expect(File.readlines(sequence, chomp: true)).to eq(%w[first second third])
    end
  end

  it "rejects a retry record standing in for the assigned multisite process" do
    Dir.mktmpdir("execution-roles-", "tmp") do |directory|
      file = "#{directory}/selected_spec.rb"
      File.write(file, 'RSpec.describe("Selected") { it("passes") {} }')
      FileUtils.mkdir_p("#{directory}/bin")
      File.write("#{directory}/bin/turbo_rspec", <<~'RUBY')
        #!/usr/bin/env ruby
        require "json"
        files = JSON.parse(ENV.fetch("ASSIGNED_FILES"))
        pid = Process.pid
        assignments = {"1" => {"files" => files, "pid" => pid}, "multisite" => {"files" => files, "pid" => pid + 1}}
        File.write(ARGV.fetch(ARGV.index("--execution-plan") + 1), JSON.generate("revision" => ENV.fetch("GITHUB_SHA"), "workers" => assignments))
        {"1" => pid, "multisite" => pid + 2}.each do |identity, record_pid|
          record = {"revision" => ENV.fetch("GITHUB_SHA"), "identity" => identity, "pid" => record_pid, "files" => files, "executed_files" => files, "examples" => 1, "failures" => []}
          File.write("#{ENV.fetch("TEST_EXECUTION_DIRECTORY")}/rspec-#{record_pid}.json", JSON.generate(record))
        end
      RUBY
      File.chmod(0o755, "#{directory}/bin/turbo_rspec")
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "backend" => [file],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => [file],
            "environment" => "core",
            "runner" => "rspec",
            "command" => ["bin/turbo_rspec"],
            "cwd" => directory,
            "env" => {
              "ASSIGNED_FILES" => JSON.generate([file]),
            },
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge("GITHUB_SHA" => revision),
          RbConfig.ruby,
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "backend",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(false)
      expect(report.slice("process_success", "missing_roles", "exact", "success")).to eq(
        "process_success" => true,
        "missing_roles" => ["multisite"],
        "exact" => false,
        "success" => false,
      )
    end
  end

  it "rejects suite errors even when a runner reports a successful retry" do
    Dir.mktmpdir("execution-", "tmp") do |directory|
      file = "#{directory}/suite_error_spec.rb"
      File.write(
        file,
        'RSpec.configure { |config| config.before(:suite) { raise "Suite setup failed" } }; RSpec.describe("Selected") { it("passes") {} }',
      )
      runner = "#{directory}/runner.rb"
      File.write(
        runner,
        'require "rspec/core"; RSpec::Core::Runner.run(["--options", "/dev/null", *ARGV]); exit 0',
      )
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "backend" => [file],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => [file],
            "environment" => "core",
            "runner" => "rspec",
            "command" => [RbConfig.ruby, runner],
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge("GITHUB_SHA" => revision),
          RbConfig.ruby,
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "backend",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(false)
      expect(report.slice("process_success", "non_example_failure", "exact", "success")).to eq(
        "process_success" => true,
        "non_example_failure" => true,
        "exact" => true,
        "success" => false,
      )
    end
  end

  it "rejects errors in generated descriptions even when RSpec reports a passing example" do
    Dir.mktmpdir("execution-", "tmp") do |directory|
      file = "#{directory}/description_error_spec.rb"
      File.write(file, <<~RUBY)
        RSpec::Matchers.define :complete_successfully do
          match { true }
          description { raise "Description failed" }
        end
        RSpec.describe "Selected" do
          it { expect(true).to complete_successfully }
        end
      RUBY
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [file],
        "jobs" => {
          "backend" => [file],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => [file],
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge("GITHUB_SHA" => revision),
          RbConfig.ruby,
          "script/ci/test_execution.rb",
          "#{directory}/plan.json",
          "#{directory}/catalog.json",
          "backend",
          "#{directory}/report.json",
        )
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(status.success?).to eq(false)
      expect(report.slice("process_success", "examples", "failures", "exact", "success")).to eq(
        "process_success" => true,
        "examples" => 1,
        "failures" => [],
        "exact" => true,
        "success" => false,
      )
      expect(report.fetch("description_errors")).to eq(["./#{file}[1:1]"])
    end
  end

  it "rejects omitted assignments and detects files added by a runner" do
    Dir.mktmpdir("execution-", "tmp") do |directory|
      files = %w[affected unrelated].map { |name| "#{directory}/#{name}_spec.rb" }
      files.each do |file|
        File.write(file, 'RSpec.describe("File") { it("passes") { expect(true).to eq(true) } }')
      end
      File.write(
        files.first,
        'require_relative "unrelated_spec"; RSpec.describe("Selected") { it("passes") { expect(true).to eq(true) } }',
      )
      revision = "b" * 40
      plan = {
        "version" => 2,
        "mode" => "select",
        "revision" => revision,
        "files" => [files.first],
        "jobs" => {
          "backend" => [],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => files,
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      File.write("#{directory}/plan.json", JSON.generate(plan))
      File.write("#{directory}/catalog.json", JSON.generate(catalog))
      command = [
        RbConfig.ruby,
        "script/ci/test_execution.rb",
        "#{directory}/plan.json",
        "#{directory}/catalog.json",
        "backend",
        "#{directory}/report.json",
      ]

      _, missing_error, missing_status =
        Open3.capture3(isolated_rspec_environment.merge("GITHUB_SHA" => revision), *command)
      plan["jobs"]["backend"] = [files.first]
      File.write("#{directory}/plan.json", JSON.generate(plan))
      _, _, extra_status =
        Open3.capture3(isolated_rspec_environment.merge("GITHUB_SHA" => revision), *command)
      report = JSON.parse(File.read("#{directory}/report.json"))

      expect(missing_status.success?).to eq(false)
      expect(missing_error).to include("Invalid or stale job assignment")
      expect(extra_status.success?).to eq(false)
      expect(report.slice("loaded", "executed_files", "exact")).to eq(
        "loaded" => files.sort,
        "executed_files" => files.sort,
        "exact" => false,
      )
    end
  end

  shared_examples "a spec loading boundary" do |variant:|
    it "distinguishes loading from compilation for #{variant} specs" do
      external = nil
      Dir.mktmpdir("execution-", "tmp") do |directory|
        fixture = directory
        if variant == "symlinked"
          external = Dir.mktmpdir("external-specs-")
          fixture = "#{directory}/linked"
          File.symlink(external, fixture)
        end
        files = %w[selected extra].map { |name| "#{fixture}/#{name}_spec.rb" }
        if variant.start_with?("temporary")
          external = Dir.mktmpdir("external-fixture-")
          files[-1] = "#{external}/extra_spec.rb"
        end
        marker = File.expand_path("#{directory}/loaded")
        extra = "File.write(#{marker.inspect}, 'loaded')\n"
        extra += "RSpec.describe('Extra', skip: true) { it('skips') {} }\n" if %w[
          skipped
          temporary_spec
        ].include?(variant)
        extra = "" if %w[compiled_empty empty_require empty_load].include?(variant)
        File.write(files.last, extra)
        loading =
          if variant.start_with?("compiled")
            'RubyVM::InstructionSequence.compile_file(File.expand_path("extra_spec.rb", __dir__))'
          elsif %w[body_only empty_load].include?(variant)
            'load File.expand_path("extra_spec.rb", __dir__)'
          else
            'require_relative "extra_spec"'
          end
        loading =
          "load #{files.last.inspect}; File.unlink(#{files.last.inspect})" if variant.start_with?(
          "temporary",
        )
        File.write(
          files.first,
          "#{loading}\nRSpec.describe('Selected') { it('passes') { expect(true).to eq(true) } }\n",
        )
        revision = "b" * 40
        plan = {
          "version" => 2,
          "mode" => "select",
          "revision" => revision,
          "files" => [files.first],
          "jobs" => {
            "backend" => [files.first],
          },
          "environments" => {
            "backend" => "core",
          },
        }
        catalog = {
          "revision" => revision,
          "jobs" => {
            "backend" => {
              "inventory" => variant.start_with?("temporary") ? [files.first] : files,
              "environment" => "core",
              "runner" => "rspec",
              "command" => %w[bundle exec rspec --options /dev/null],
            },
          },
        }
        File.write("#{directory}/plan.json", JSON.generate(plan))
        File.write("#{directory}/catalog.json", JSON.generate(catalog))
        environment = isolated_rspec_environment.merge("GITHUB_SHA" => revision)
        if variant == "cached_require"
          environment["BOOTSNAP_CACHE_DIR"] = File.expand_path("#{directory}/cache")
          _, warm_error, warm_status =
            Open3.capture3(
              environment,
              RbConfig.ruby,
              "-rbootsnap/setup",
              "-e",
              "require ARGV.fetch(0)",
              File.expand_path(files.last),
            )
          expect(warm_status.success?).to eq(true), warm_error
          File.unlink(marker)
          catalog
            .fetch("jobs")
            .fetch("backend")
            .fetch("command")
            .concat(%w[--require bootsnap/setup])
          File.write("#{directory}/catalog.json", JSON.generate(catalog))
        end

        _, _, status =
          Open3.capture3(
            environment,
            RbConfig.ruby,
            "script/ci/test_execution.rb",
            "#{directory}/plan.json",
            "#{directory}/catalog.json",
            "backend",
            "#{directory}/report.json",
          )
        report = JSON.parse(File.read("#{directory}/report.json"))

        compiled_only = variant.start_with?("compiled")
        only_selected = compiled_only || variant == "temporary_fixture"
        expect(status.success?).to eq(only_selected)
        expect(File.file?(marker)).to eq(
          !compiled_only && !%w[empty_require empty_load].include?(variant),
        )
        expect(report.slice("loaded", "executed_files", "exact")).to eq(
          "loaded" => only_selected ? [files.first] : files.sort,
          "executed_files" => [files.first],
          "exact" => only_selected,
        )
      end
    ensure
      FileUtils.remove_entry(external) if external
    end
  end

  it_behaves_like "a spec loading boundary", variant: "skipped"
  it_behaves_like "a spec loading boundary", variant: "body_only"
  it_behaves_like "a spec loading boundary", variant: "compiled_only"
  it_behaves_like "a spec loading boundary", variant: "compiled_empty"
  it_behaves_like "a spec loading boundary", variant: "empty_require"
  it_behaves_like "a spec loading boundary", variant: "empty_load"
  it_behaves_like "a spec loading boundary", variant: "temporary_fixture"
  it_behaves_like "a spec loading boundary", variant: "temporary_spec"
  it_behaves_like "a spec loading boundary", variant: "symlinked"
  it_behaves_like "a spec loading boundary", variant: "cached_require"
end

RSpec.describe TestMapping do
  it "requires every execution role before publishing a complete mapping" do
    Dir.mktmpdir("mapping-roles-") do |directory|
      revision = "a" * 40
      files = ["spec/a_spec.rb"]
      job = { "inventory" => files, "environment" => "core", "command" => ["bin/turbo_rspec"] }
      catalog = { "revision" => revision, "jobs" => { "backend" => job } }
      manifest = {
        "revision" => revision,
        "workers" => {
          "1" => {
            "files" => files,
            "pid" => 1,
          },
          "multisite" => {
            "files" => files,
            "pid" => 2,
          },
        },
      }
      File.write("#{directory}/execution-manifest.json", JSON.generate(manifest))
      worker = {
        "version" => 5,
        "revision" => revision,
        "environment" => "core",
        "complete" => true,
        "identity" => "1",
        "pid" => 1,
        "files" => files,
        "dependencies" => {
          files.first => [],
        },
        "dependency_graph" => {
          "version" => 1,
          "paths" => [],
          "callers" => [],
        },
        "tests" => {
          files.first => [],
        },
        "initialization_sources" => [],
        "boot_lines" => {
        },
        "shared_files" => [],
      }
      File.write("#{directory}/rspec-1.json", JSON.generate(worker))
      File.write("#{directory}/worker-1.json", JSON.generate(worker))
      arguments = {
        catalog: catalog,
        job_name: "backend",
        directory: directory,
        execution_directory: directory,
        output: "#{directory}/mapping.json",
      }

      expect { described_class.merge(**arguments) }.to raise_error(
        "Mapping execution is missing a required role",
      )
      worker["identity"] = "multisite"
      worker["pid"] = 3
      File.write("#{directory}/rspec-3.json", JSON.generate(worker))
      File.write("#{directory}/worker-3.json", JSON.generate(worker))

      expect { described_class.merge(**arguments) }.to raise_error(
        "Mapping execution is missing a required role",
      )
      worker["pid"] = 2
      File.write("#{directory}/rspec-2.json", JSON.generate(worker))
      File.write("#{directory}/worker-2.json", JSON.generate(worker))
      described_class.merge(**arguments)
      mapping = JSON.parse(File.read("#{directory}/mapping.json"))

      expect(mapping.slice("complete", "tests")).to eq(
        "complete" => true,
        "tests" => {
          files.first => [],
        },
      )
    end
  end
end

RSpec.describe TestInventory do
  it "discovers runnable core tests while keeping helpers as application inputs" do
    Dir.mktmpdir("frontend-inventory-") do |directory|
      %w[
        .github/workflows
        frontend/discourse/tests/helpers
        frontend/discourse/tests/unit
      ].each { |path| FileUtils.mkdir_p("#{directory}/#{path}") }
      %w[
        Gemfile
        Gemfile.lock
        pnpm-lock.yaml
        .github/workflows/tests.yml
        .github/workflows/migration-tests.yml
        frontend/discourse/tests/helpers/component-test.js
        frontend/discourse/tests/unit/component-test.js
      ].each { |path| File.write("#{directory}/#{path}", "fixture") }
      system("git", "-C", directory, "init", "--quiet", exception: true)
      system(
        "git",
        "-C",
        directory,
        "-c",
        "user.name=Inventory test",
        "-c",
        "user.email=test@example.invalid",
        "-c",
        "commit.gpgsign=false",
        "-c",
        "core.hooksPath=/dev/null",
        "commit",
        "--allow-empty",
        "--quiet",
        "-m",
        "Fixture",
        exception: true,
      )

      catalog = Dir.chdir(directory) { described_class.catalog(revision: "b" * 40) }

      expect(catalog.fetch("jobs").fetch("core-frontend").fetch("inventory")).to eq(
        ["frontend/discourse/tests/unit/component-test.js"],
      )
      expect(
        described_class.test_file?("frontend/discourse/tests/helpers/component-test.js"),
      ).to eq(false)
      systems = catalog.fetch("jobs").select { |name, _| name.end_with?("-system") }
      expect(systems.length).to eq(5)
      migrations = catalog.fetch("jobs").select { |name, _| name.start_with?("migrations-") }
      expect(migrations.length).to eq(8)
      expect(
        migrations
          .select { |name, _| name.end_with?("-plain") }
          .values
          .map { |job| job.fetch("order") }
          .uniq,
      ).to eq(["defined"])
      expect(
        migrations
          .select { |name, _| name.end_with?("-rails") }
          .values
          .map { |job| job.fetch("order") }
          .uniq,
      ).to eq(["random"])
      expect(
        systems
          .values
          .map do |job|
            job.fetch("env").slice(
              "CHECKOUT_TIMEOUT",
              "RAILS_ENABLE_TEST_LOG",
              "RAILS_TEST_LOG_LEVEL",
            )
          end
          .uniq,
      ).to eq(
        [
          {
            "CHECKOUT_TIMEOUT" => "10",
            "RAILS_ENABLE_TEST_LOG" => "1",
            "RAILS_TEST_LOG_LEVEL" => "error",
          },
        ],
      )
    end
  end

  it "rejects mappings recorded by a different collection or runner implementation" do
    Dir.mktmpdir("runtime-environment-") do |directory|
      %w[.github/workflows script/ci spec].each { |path| FileUtils.mkdir_p("#{directory}/#{path}") }
      %w[
        Gemfile
        Gemfile.lock
        pnpm-lock.yaml
        .github/workflows/tests.yml
        .github/workflows/migration-tests.yml
        spec/a_spec.rb
        spec/b_spec.rb
      ].each { |path| File.write("#{directory}/#{path}", "fixture") }
      runtime = "#{directory}/script/ci/ruby_dependencies.rb"
      File.write(runtime, "first implementation")
      system("git", "-C", directory, "init", "--quiet", exception: true)
      system(
        "git",
        "-C",
        directory,
        "-c",
        "user.name=Runtime test",
        "-c",
        "user.email=test@example.invalid",
        "-c",
        "commit.gpgsign=false",
        "-c",
        "core.hooksPath=/dev/null",
        "commit",
        "--allow-empty",
        "--quiet",
        "-m",
        "Fixture",
        exception: true,
      )
      baseline =
        Dir
          .chdir(directory) { described_class.catalog(revision: "b" * 40) }
          .fetch("jobs")
          .fetch("core-backend")
      File.write(runtime, "second implementation")
      current =
        Dir
          .chdir(directory) { described_class.catalog(revision: "b" * 40) }
          .fetch("jobs")
          .fetch("core-backend")
      mapping = {
        "version" => 2,
        "complete" => true,
        "revision" => "a" * 40,
        "environment" => baseline.fetch("environment"),
        "tests" => {
          "spec/a_spec.rb" => ["lib/producer.rb"],
          "spec/b_spec.rb" => [],
        },
        "sources" => ["lib/producer.rb"],
        "source_dependencies" => {
        },
        "initialization_sources" => [],
        "shared_files" => [],
      }
      job =
        current.merge(
          "mapping" => mapping,
          "mapping_changes" => [],
          "verified_sources" => ["lib/producer.rb"],
        )
      input = {
        "revision" => "b" * 40,
        "mode" => "select",
        "main" => false,
        "changes" => ["lib/producer.rb"],
        "test_changes" => [],
        "deleted_tests" => [],
        "jobs" => {
          "core-backend" => job,
        },
      }
      control =
        input.merge(
          "jobs" => {
            "core-backend" => job.merge("environment" => baseline.fetch("environment")),
          },
        )

      expect(TestSelection::Planner.new(control).plan.fetch("files")).to eq(["spec/a_spec.rb"])
      expect(current.fetch("environment")).not_to eq(baseline.fetch("environment"))
      expect(TestSelection::Planner.new(input).plan.fetch("files")).to eq(
        %w[spec/a_spec.rb spec/b_spec.rb],
      )
    end
  end

  it "keeps the application revision when external repositories are present" do
    Dir.mktmpdir("inventory-") do |root|
      %w[.github/workflows plugins/external].each { |path| FileUtils.mkdir_p("#{root}/#{path}") }
      %w[
        Gemfile
        Gemfile.lock
        pnpm-lock.yaml
        .github/workflows/tests.yml
        .github/workflows/migration-tests.yml
      ].each { |path| File.write("#{root}/#{path}", "fixture") }
      [root, "#{root}/plugins/external"].each do |directory|
        File.write("#{directory}/README.md", "fixture")
        system("git", "-C", directory, "init", "--quiet", exception: true)
        system("git", "-C", directory, "add", "README.md", exception: true)
        system(
          "git",
          "-C",
          directory,
          "-c",
          "user.name=Inventory test",
          "-c",
          "user.email=test@example.invalid",
          "-c",
          "commit.gpgsign=false",
          "-c",
          "core.hooksPath=/dev/null",
          "commit",
          "--quiet",
          "-m",
          "Fixture",
          exception: true,
        )
      end
      revision = "b" * 40

      result = Dir.chdir(root) { described_class.catalog(revision: revision) }

      expect(result.fetch("revision")).to eq(revision)
      expect(result.fetch("checkouts").fetch("plugins/external")).to match(/\A[0-9a-f]{40}\z/)
    end
  end
end

RSpec.describe "Test workflow preparation" do
  include RSpecSubprocessEnvironment
  it "protects new declarations without mappings through both preparation entry points" do
    prepare = File.expand_path("../../script/ci/test_prepare.rb", __dir__)
    Dir.mktmpdir("mixed-workflow-") do |directory|
      %w[.github/workflows spec/lib migrations/core/spec].each do |path|
        FileUtils.mkdir_p("#{directory}/#{path}")
      end
      %w[
        Gemfile
        Gemfile.lock
        pnpm-lock.yaml
        .github/workflows/tests.yml
        .github/workflows/migration-tests.yml
      ].each { |path| File.write("#{directory}/#{path}", "fixture") }
      git =
        lambda do |*arguments|
          output, status =
            Open3.capture2e(
              "git",
              "-C",
              directory,
              "-c",
              "user.name=Workflow test",
              "-c",
              "user.email=test@example.invalid",
              "-c",
              "commit.gpgsign=false",
              "-c",
              "core.hooksPath=/dev/null",
              *arguments,
            )
          raise output unless status.success?
          output.strip
        end
      %w[spec/lib/existing_spec.rb migrations/core/spec/existing_spec.rb].each do |path|
        File.write("#{directory}/#{path}", "RSpec.describe('Existing') {}")
      end
      git.call("init", "--quiet")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Base")
      base = git.call("rev-parse", "HEAD")
      files = %w[spec/lib/changed_spec.rb migrations/core/spec/changed_spec.rb]
      files.each { |path| File.write("#{directory}/#{path}", "RSpec.describe('Changed') {}") }
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Mixed tests")
      revision = git.call("rev-parse", "HEAD")
      environment = {
        "GITHUB_SHA" => revision,
        "GITHUB_REF" => "refs/pull/1/merge",
        "GITHUB_EVENT_NAME" => "pull_request",
        "GITHUB_EVENT_PATH" => "#{directory}/event.json",
        "TEST_SELECTION_MODE" => "select",
        "TEST_SELECTION_AUDIT_PERCENT" => "0",
        "GITHUB_OUTPUT" => nil,
      }

      %w[main stable].each do |branch|
        File.write(
          "#{directory}/event.json",
          JSON.generate("pull_request" => { "base" => { "ref" => branch, "sha" => base } }),
        )
        %w[tests migration-tests]
          .zip(files)
          .each do |workflow, expected|
            destination = "#{directory}/#{branch}-#{workflow}"
            output, status =
              Open3.capture2e(
                isolated_rspec_environment.merge(environment),
                RbConfig.ruby,
                prepare,
                workflow,
                destination,
                chdir: directory,
              )

            expect(status.success?).to eq(true), output
            plan = JSON.parse(File.read("#{destination}/plan.json"))
            expected_files = [expected, expected.sub("changed_spec.rb", "existing_spec.rb")]
            expect(plan.fetch("files")).to eq(expected_files)
            expect(plan.fetch("jobs").values.flatten.uniq).to eq(expected_files)
          end
      end
    end
  end
end

RSpec.describe TestJob do
  include RSpecSubprocessEnvironment
  it "reuses only validated identical audit assignments" do
    Dir.mktmpdir("audit-reuse-", "tmp") do |directory|
      counter = "#{File.expand_path(directory)}/counter"
      spec = "#{directory}/selected_spec.rb"
      File.write(
        spec,
        "RSpec.describe('Counter') { it('executes') { File.open(#{counter.dump}, 'a') { |file| file.puts('run') } } }",
      )
      revision = "b" * 40
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => [spec],
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      plan = {
        "version" => 2,
        "revision" => revision,
        "mode" => "audit",
        "files" => [spec],
        "jobs" => {
          "backend" => [spec],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      plan_path = "#{directory}/plan.json"
      catalog_path = "#{directory}/catalog.json"
      File.write(plan_path, JSON.generate(plan))
      File.write("#{plan_path}.reference.json", JSON.generate(plan.merge("mode" => "full")))
      File.write(catalog_path, JSON.generate(catalog))
      command = [
        RbConfig.ruby,
        File.expand_path("../../script/ci/test_job.rb", __dir__),
        plan_path,
        catalog_path,
        "backend",
      ]
      environment =
        isolated_rspec_environment.merge(
          "GITHUB_SHA" => revision,
          "GITHUB_REF" => "refs/pull/1/merge",
          "GITHUB_EVENT_NAME" => "pull_request",
        )

      output, error, status = Open3.capture3(environment, *command, "#{directory}/same")
      audit = JSON.parse(File.read("#{directory}/same/audit.json"))

      expect(status.success?).to eq(true), output + error
      expect(File.readlines(counter).length).to eq(1)
      expect(audit.slice("exact", "comparison_complete", "candidate_reused_reference")).to eq(
        "exact" => true,
        "comparison_complete" => true,
        "candidate_reused_reference" => true,
      )

      File.write(plan_path, JSON.generate(plan.merge("environments" => { "backend" => "wrong" })))
      _, error, status = Open3.capture3(environment, *command, "#{directory}/invalid")

      expect(status.success?).to eq(false)
      expect(error).to include("Invalid or stale job assignment")
      expect(File.exist?("#{directory}/invalid/audit.json")).to eq(false)

      omitted = "#{directory}/omitted_spec.rb"
      File.write(omitted, File.read(spec).sub("Counter", "Other counter"))
      inventory = [spec, omitted].sort
      catalog["jobs"]["backend"]["inventory"] = inventory
      File.write(catalog_path, JSON.generate(catalog))
      File.write(plan_path, JSON.generate(plan))
      File.write(
        "#{plan_path}.reference.json",
        JSON.generate(
          plan.merge("mode" => "full", "files" => inventory, "jobs" => { "backend" => inventory }),
        ),
      )
      before = File.readlines(counter).length
      output, error, status = Open3.capture3(environment, *command, "#{directory}/subset")
      audit = JSON.parse(File.read("#{directory}/subset/audit.json"))

      expect(status.success?).to eq(true), output + error
      expect(File.readlines(counter).length - before).to eq(3)
      expect(audit.fetch("candidate_reused_reference")).to eq(false)
    end
  end

  it "marks an audit incomplete when the process exits after reporting passing examples" do
    Dir.mktmpdir("audit-late-exit-", "tmp") do |directory|
      selected = "#{directory}/selected_spec.rb"
      omitted = "#{directory}/omitted_spec.rb"
      File.write(
        selected,
        'RSpec.describe("Selected") { it("passes") { expect(true).to eq(true) } }',
      )
      File.write(
        omitted,
        'at_exit { exit 1 }; RSpec.describe("Omitted") { it("passes") { expect(true).to eq(true) } }',
      )
      revision = "b" * 40
      inventory = [selected, omitted].sort
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => inventory,
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      plan = {
        "version" => 2,
        "revision" => revision,
        "mode" => "audit",
        "files" => [selected],
        "jobs" => {
          "backend" => [selected],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      plan_path = "#{directory}/plan.json"
      catalog_path = "#{directory}/catalog.json"
      File.write(plan_path, JSON.generate(plan))
      File.write(
        "#{plan_path}.reference.json",
        JSON.generate(
          plan.merge("mode" => "full", "files" => inventory, "jobs" => { "backend" => inventory }),
        ),
      )
      File.write(catalog_path, JSON.generate(catalog))
      command = [
        RbConfig.ruby,
        File.expand_path("../../script/ci/test_job.rb", __dir__),
        plan_path,
        catalog_path,
        "backend",
        "#{directory}/reports",
      ]

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge(
            "GITHUB_SHA" => revision,
            "GITHUB_REF" => "refs/pull/1/merge",
            "GITHUB_EVENT_NAME" => "pull_request",
          ),
          *command,
        )
      audit = JSON.parse(File.read("#{directory}/reports/audit.json"))

      expect(status.success?).to eq(false)
      expect(audit.fetch("exact")).to eq(true)
      expect(audit.fetch("reference_unreported_failure")).to eq(true)
      expect(audit.fetch("comparison_complete")).to eq(false)
    end
  end

  it "traces a full main run only when explicitly recording a producer" do
    Dir.mktmpdir("main-producer-", "spec") do |directory|
      spec = "#{directory}/main_spec.rb"
      File.write(spec, 'RSpec.describe("Main") { it("runs") { expect(true).to eq(true) } }')
      revision = "b" * 40
      inventory = [spec]
      job_name = "producer-probe"
      mapping_path = "tmp/test-mappings/#{job_name}.json"
      catalog = {
        "revision" => revision,
        "jobs" => {
          job_name => {
            "inventory" => inventory,
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      plan = {
        "version" => 2,
        "revision" => revision,
        "mode" => "full",
        "files" => inventory,
        "jobs" => {
          job_name => inventory,
        },
        "environments" => {
          job_name => "core",
        },
      }
      plan_path = "#{directory}/plan.json"
      catalog_path = "#{directory}/catalog.json"
      File.write(plan_path, JSON.generate(plan))
      File.write(catalog_path, JSON.generate(catalog))
      environment =
        isolated_rspec_environment.merge(
          "GITHUB_SHA" => revision,
          "GITHUB_REF" => "refs/heads/main",
          "GITHUB_EVENT_NAME" => "push",
        )
      command = [
        RbConfig.ruby,
        File.expand_path("../../script/ci/test_job.rb", __dir__),
        plan_path,
        catalog_path,
        job_name,
      ]
      FileUtils.rm_f(mapping_path)

      output, error, status = Open3.capture3(environment, *command, "#{directory}/normal")
      expect(status.success?).to eq(true), output + error
      normal = JSON.parse(File.read("#{directory}/normal/execution.json"))
      expect(normal.fetch("loaded")).to eq(inventory)
      expect(Dir["#{directory}/normal/raw/*.json"]).to eq([])
      expect(File.exist?(mapping_path)).to eq(false)
      output, error, status =
        Open3.capture3(
          environment.merge("TEST_MAPPING_COLLECT" => "1"),
          *command,
          "#{directory}/producer",
        )
      expect(status.success?).to eq(true), output + error
      producer = JSON.parse(File.read("#{directory}/producer/execution.json"))
      mapping = JSON.parse(File.read(mapping_path))
      expect(producer.fetch("loaded")).to eq(inventory)
      expect(mapping.fetch("complete")).to eq(true)
      expect(mapping.fetch("tests").keys).to eq(inventory)
    ensure
      FileUtils.rm_f(mapping_path) if mapping_path
    end
  end

  it "reports a reference load error as an incomplete audit comparison" do
    Dir.mktmpdir("audit-load-error-", "tmp") do |directory|
      selected = "#{directory}/selected_spec.rb"
      omitted = "#{directory}/omitted_spec.rb"
      File.write(
        selected,
        'RSpec.describe("Selected") { it("passes") { expect(true).to eq(true) } }',
      )
      File.write(omitted, 'raise "Unselected file failed while loading"')
      revision = "b" * 40
      inventory = [selected, omitted].sort
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => inventory,
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      plan = {
        "version" => 2,
        "revision" => revision,
        "mode" => "audit",
        "files" => [selected],
        "jobs" => {
          "backend" => [selected],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      plan_path = "#{directory}/plan.json"
      catalog_path = "#{directory}/catalog.json"
      File.write(plan_path, JSON.generate(plan))
      File.write(
        "#{plan_path}.reference.json",
        JSON.generate(
          plan.merge("mode" => "full", "files" => inventory, "jobs" => { "backend" => inventory }),
        ),
      )
      File.write(catalog_path, JSON.generate(catalog))
      command = [
        RbConfig.ruby,
        File.expand_path("../../script/ci/test_job.rb", __dir__),
        plan_path,
        catalog_path,
        "backend",
        "#{directory}/reports",
      ]

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge(
            "GITHUB_SHA" => revision,
            "GITHUB_REF" => "refs/pull/1/merge",
            "GITHUB_EVENT_NAME" => "pull_request",
          ),
          *command,
        )
      audit = JSON.parse(File.read("#{directory}/reports/audit.json"))

      expect(status.success?).to eq(false)
      expect(
        audit.slice(
          "reference_success",
          "candidate_success",
          "reference_unreported_failure",
          "candidate_unreported_failure",
          "comparison_complete",
        ),
      ).to eq(
        "reference_success" => false,
        "candidate_success" => true,
        "reference_unreported_failure" => true,
        "candidate_unreported_failure" => false,
        "comparison_complete" => false,
      )
    end
  end

  it "runs the full audit reference and records a failure omitted by the candidate" do
    Dir.mktmpdir("audit-", "tmp") do |directory|
      selected = "#{directory}/selected_spec.rb"
      omitted = "#{directory}/omitted_spec.rb"
      File.write(
        selected,
        'RSpec.describe("Selected") { it("fails") { expect(true).to eq(false) } }',
      )
      File.write(
        omitted,
        'RSpec.describe("Omitted") { before(:context) { raise "Actual omitted context failure" }; it("fails before its body") {} }',
      )
      revision = "b" * 40
      inventory = [selected, omitted].sort
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => inventory,
            "environment" => "core",
            "runner" => "rspec",
            "command" => %w[bundle exec rspec --options /dev/null],
          },
        },
      }
      plan = {
        "version" => 2,
        "revision" => revision,
        "mode" => "audit",
        "files" => [selected],
        "jobs" => {
          "backend" => [selected],
        },
        "environments" => {
          "backend" => "core",
        },
      }
      plan_path = "#{directory}/plan.json"
      catalog_path = "#{directory}/catalog.json"
      File.write(plan_path, JSON.generate(plan))
      File.write(
        "#{plan_path}.reference.json",
        JSON.generate(
          plan.merge("mode" => "full", "files" => inventory, "jobs" => { "backend" => inventory }),
        ),
      )
      File.write(catalog_path, JSON.generate(catalog))
      command = [
        RbConfig.ruby,
        File.expand_path("../../script/ci/test_job.rb", __dir__),
        plan_path,
        catalog_path,
        "backend",
        "#{directory}/reports",
      ]

      _, _, status =
        Open3.capture3(
          isolated_rspec_environment.merge(
            "GITHUB_SHA" => revision,
            "GITHUB_REF" => "refs/pull/1/merge",
            "GITHUB_EVENT_NAME" => "pull_request",
          ),
          *command,
        )
      audit = JSON.parse(File.read("#{directory}/reports/audit.json"))
      reference = JSON.parse(File.read("#{directory}/reports/reference.json"))
      candidate = JSON.parse(File.read("#{directory}/reports/candidate.json"))

      expect(status.success?).to eq(false)
      expect(reference.fetch("loaded")).to eq(inventory)
      expect(candidate.fetch("loaded")).to eq([selected])
      expect(reference.fetch("examples")).to eq(2)
      expect(reference.fetch("executed_files")).to eq(inventory)
      expect(candidate.fetch("examples")).to eq(1)
      expect(audit.fetch("missed_failures")).to eq(["./#{omitted}[1:1]"])
      expect(audit.slice("exact", "comparison_complete")).to eq(
        "exact" => true,
        "comparison_complete" => true,
      )
    end
  end
end

RSpec.describe TestPlan do
  it "routes new test definitions only to environments that load them" do
    Dir.mktmpdir("preloaded-spec-helpers-") do |directory|
      FileUtils.mkdir_p(
        [
          "#{directory}/spec",
          "#{directory}/migrations/core/spec",
          "#{directory}/frontend/discourse/tests/unit",
          "#{directory}/frontend/asset-processor",
          "#{directory}/tmp",
        ],
      )
      File.write("#{directory}/.gitignore", "tmp/\n")
      File.write(
        "#{directory}/spec/existing_spec.rb",
        'RSpec.describe("Existing") { it("passes") {} }',
      )
      File.write(
        "#{directory}/migrations/core/spec/existing_spec.rb",
        'RSpec.describe("Existing migration") { it("passes") {} }',
      )
      File.write(
        "#{directory}/frontend/discourse/tests/unit/existing-test.js",
        "globalThis.sharedTestValue = 'original';",
      )
      File.write(
        "#{directory}/frontend/asset-processor/existing.test.mjs",
        "globalThis.sharedTestValue = 'original';",
      )
      git =
        lambda do |*arguments|
          output, status =
            Open3.capture2e(
              "git",
              "-C",
              directory,
              "-c",
              "user.name=Plan test",
              "-c",
              "user.email=test@example.invalid",
              "-c",
              "commit.gpgsign=false",
              "-c",
              "core.hooksPath=/dev/null",
              *arguments,
            )
          raise output unless status.success?
          output.strip
        end
      git.call("init", "--quiet")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Existing framework setup")
      base = git.call("rev-parse", "HEAD")
      core_spec = "spec/added_spec.rb"
      migration_spec = "migrations/core/spec/added_spec.rb"
      frontend_test = "frontend/discourse/tests/unit/added-test.js"
      asset_test = "frontend/asset-processor/added.test.mjs"
      File.write(
        "#{directory}/#{core_spec}",
        "require 'rails_helper'\nRSpec.describe('Added') { it('passes') {} }\n",
      )
      File.write(
        "#{directory}/#{migration_spec}",
        "require 'spec_helper'\nRSpec.describe('Added migration') { it('passes') {} }\n",
      )
      File.write("#{directory}/#{frontend_test}", "globalThis.sharedTestValue = 'changed';")
      File.write("#{directory}/#{asset_test}", "globalThis.sharedTestValue = 'changed';")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Add isolated specs")
      revision = git.call("rev-parse", "HEAD")

      Dir.chdir(directory) do
        jobs =
          TestInventory
            .jobs(bundled: [])
            .to_h { |name, job| [name, job.merge("environment" => name)] }
        File.write(
          "tmp/catalog.json",
          JSON.generate("revision" => revision, "repository_catalog" => true, "jobs" => jobs),
        )
        FileUtils.mkdir_p("tmp/mappings")
        jobs.each do |name, job|
          mapping = {
            "version" => 2,
            "revision" => base,
            "environment" => name,
            "complete" => true,
            "tests" =>
              (
                job.fetch("inventory") - [core_spec, migration_spec, frontend_test, asset_test]
              ).to_h { |path| [path, []] },
            "source_checks" => {
            },
            "sources" => [],
            "initialization_sources" => [],
            "shared_files" => [],
            "source_dependencies" => {
            },
          }
          File.write("tmp/mappings/#{name}.json", JSON.generate(mapping))
        end
        described_class.prepare(
          catalog_path: "tmp/catalog.json",
          mapping_directory: "tmp/mappings",
          base: base,
          revision: revision,
          output: "tmp/plan.json",
          mode: "select",
          main: false,
        )
      end
      plan = JSON.parse(File.read("#{directory}/tmp/plan.json"))

      expect(plan.fetch("jobs").reject { |_, files| files.empty? }).to eq(
        "core-backend" => [core_spec, "spec/existing_spec.rb"],
        "migrations-core-plain" => [migration_spec, "migrations/core/spec/existing_spec.rb"],
        "migrations-core-rails" => [migration_spec, "migrations/core/spec/existing_spec.rb"],
        "core-frontend" => [frontend_test, "frontend/discourse/tests/unit/existing-test.js"],
        "asset-processor" => [asset_test, "frontend/asset-processor/existing.test.mjs"],
      )
      expect(plan.fetch("files")).to eq(
        [
          asset_test,
          "frontend/asset-processor/existing.test.mjs",
          frontend_test,
          "frontend/discourse/tests/unit/existing-test.js",
          migration_spec,
          "migrations/core/spec/existing_spec.rb",
          core_spec,
          "spec/existing_spec.rb",
        ],
      )
    end
  end

  it "routes removed shared setup only to its previous environment without a mapping" do
    Dir.mktmpdir("removed-shared-setup-") do |directory|
      FileUtils.mkdir_p(
        [
          "#{directory}/spec/system",
          "#{directory}/frontend/discourse/tests/unit",
          "#{directory}/tmp",
        ],
      )
      File.write("#{directory}/.gitignore", "tmp/\n")
      File.write(
        "#{directory}/spec/setup_spec.rb",
        'RSpec.configure { |config| config.before(:suite) { ENV["SHARED_SETUP"] = "configured" } }; RSpec.describe("Setup") { it("passes") {} }',
      )
      File.write(
        "#{directory}/spec/reader_spec.rb",
        'RSpec.describe("Reader") { it("uses setup") { expect(ENV["SHARED_SETUP"]).to eq("configured") } }',
      )
      File.write(
        "#{directory}/spec/system/browser_spec.rb",
        'RSpec.describe("Browser") { it("has separate setup") { expect(ENV["SHARED_SETUP"]).to eq(nil) } }',
      )
      frontend_setup = "frontend/discourse/tests/unit/setup-test.js"
      frontend_reader = "frontend/discourse/tests/unit/reader-test.js"
      File.write("#{directory}/#{frontend_setup}", "globalThis.sharedTestValue = 'original';")
      File.write("#{directory}/#{frontend_reader}", "globalThis.sharedTestValue;")
      git =
        lambda do |*arguments|
          output, status =
            Open3.capture2e(
              "git",
              "-C",
              directory,
              "-c",
              "user.name=Plan test",
              "-c",
              "user.email=test@example.invalid",
              "-c",
              "commit.gpgsign=false",
              "-c",
              "core.hooksPath=/dev/null",
              *arguments,
            )
          raise output unless status.success?
          output.strip
        end
      git.call("init", "--quiet")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Original suite setup")
      base = git.call("rev-parse", "HEAD")
      File.unlink("#{directory}/spec/setup_spec.rb")
      File.unlink("#{directory}/#{frontend_setup}")
      git.call("add", "-A")
      git.call("commit", "--quiet", "-m", "Remove shared setup spec")
      revision = git.call("rev-parse", "HEAD")
      catalog = {
        "revision" => revision,
        "repository_catalog" => true,
        "jobs" => {
          "core-backend" => {
            "inventory" => ["spec/reader_spec.rb"],
            "environment" => "backend",
            "runner" => "rspec",
          },
          "core-system" => {
            "inventory" => ["spec/system/browser_spec.rb"],
            "environment" => "system",
            "runner" => "rspec",
          },
          "core-frontend" => {
            "inventory" => [frontend_reader],
            "environment" => "frontend",
            "runner" => "qunit",
          },
        },
      }
      File.write("#{directory}/tmp/catalog.json", JSON.generate(catalog))

      Dir.chdir(directory) do
        described_class.prepare(
          catalog_path: "tmp/catalog.json",
          mapping_directory: "tmp/mappings",
          base: base,
          revision: revision,
          output: "tmp/plan.json",
          mode: "select",
          main: false,
        )
      end
      result = JSON.parse(File.read("#{directory}/tmp/plan.json"))

      expect(result.fetch("files")).to eq([frontend_reader, "spec/reader_spec.rb"])
      expect(result.fetch("jobs")).to eq(
        "core-backend" => ["spec/reader_spec.rb"],
        "core-system" => [],
        "core-frontend" => [frontend_reader],
      )
      expect(result.fetch("reasons").fetch("spec/reader_spec.rb")).to eq(
        ["Shared test setup changed: spec/setup_spec.rb"],
      )
      expect(result.fetch("reasons").fetch(frontend_reader)).to eq(
        ["Shared test setup changed: #{frontend_setup}"],
      )
    end
  end

  it "protects renamed RSpec definitions alongside mapped application changes" do
    Dir.mktmpdir("rename-plan-") do |directory|
      FileUtils.mkdir_p(["#{directory}/lib", "#{directory}/spec", "#{directory}/tmp/mappings"])
      File.write("#{directory}/.gitignore", "tmp/\n")
      File.write(
        "#{directory}/lib/changed.rb",
        "module RenamedPlanSource; def self.value; :original; end; end",
      )
      %w[affected old unrelated].each do |name|
        File.write("#{directory}/spec/#{name}_spec.rb", "RSpec.describe('#{name}') {}")
      end
      git =
        lambda do |*arguments|
          output, status =
            Open3.capture2e(
              "git",
              "-C",
              directory,
              "-c",
              "user.name=Plan test",
              "-c",
              "user.email=test@example.invalid",
              "-c",
              "commit.gpgsign=false",
              "-c",
              "core.hooksPath=/dev/null",
              *arguments,
            )
          raise output unless status.success?
          output.strip
        end
      git.call("init", "--quiet")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Base")
      base = git.call("rev-parse", "HEAD")
      description = RspecSourceStructure.describe("#{directory}/lib/changed.rb")
      mapping = {
        "version" => 2,
        "complete" => true,
        "revision" => base,
        "environment" => "core",
        "tests" => {
          "spec/affected_spec.rb" => ["lib/changed.rb"],
          "spec/old_spec.rb" => [],
          "spec/unrelated_spec.rb" => [],
        },
        "sources" => ["lib/changed.rb"],
        "source_dependencies" => {
        },
        "source_checks" => {
          "lib/changed.rb" => description,
        },
        "initialization_sources" => [],
        "shared_files" => [],
      }
      File.write("#{directory}/tmp/mappings/backend.json", JSON.generate(mapping))
      File.rename("#{directory}/spec/old_spec.rb", "#{directory}/spec/renamed_spec.rb")
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Rename spec")
      renamed_base = git.call("rev-parse", "HEAD")
      File.write(
        "#{directory}/lib/changed.rb",
        File.read("#{directory}/lib/changed.rb").sub(":original", ":changed"),
      )
      git.call("add", ".")
      git.call("commit", "--quiet", "-m", "Rename and application change")
      revision = git.call("rev-parse", "HEAD")
      inventory = %w[spec/affected_spec.rb spec/renamed_spec.rb spec/unrelated_spec.rb]
      catalog = {
        "revision" => revision,
        "jobs" => {
          "backend" => {
            "inventory" => inventory,
            "environment" => "core",
            "runner" => "rspec",
          },
        },
      }
      File.write("#{directory}/tmp/catalog.json", JSON.generate(catalog))

      [base, renamed_base].each do |pr_base|
        Dir.chdir(directory) do
          described_class.prepare(
            catalog_path: "tmp/catalog.json",
            mapping_directory: "tmp/mappings",
            base: pr_base,
            revision: revision,
            output: "tmp/plan.json",
            mode: "select",
            main: false,
          )
        end

        expect(JSON.parse(File.read("#{directory}/tmp/plan.json")).fetch("files")).to eq(
          %w[spec/affected_spec.rb spec/renamed_spec.rb spec/unrelated_spec.rb],
        )
      end
    end
  end

  it "uses the full job inventory when cached mapping metadata is malformed" do
    Dir.mktmpdir("malformed-mapping-") do |directory|
      FileUtils.mkdir_p("#{directory}/mappings")
      catalog = {
        "revision" => "b" * 40,
        "jobs" => {
          "backend" => {
            "inventory" => %w[spec/a_spec.rb spec/b_spec.rb],
            "environment" => "core",
          },
        },
      }
      File.write("#{directory}/catalog.json", JSON.generate(catalog))
      allow(Open3).to receive(:capture2).and_return(
        ["lib/changed.rb\0", instance_double(Process::Status, success?: true)],
      )
      [
        [],
        {},
        { "revision" => 42 },
        { "revision" => "a" * 40, "source_checks" => [] },
      ].each do |mapping|
        File.write("#{directory}/mappings/backend.json", JSON.generate(mapping))

        described_class.prepare(
          catalog_path: "#{directory}/catalog.json",
          mapping_directory: "#{directory}/mappings",
          base: "a" * 40,
          revision: "b" * 40,
          output: "#{directory}/plan.json",
          mode: "select",
          main: false,
        )

        expect(JSON.parse(File.read("#{directory}/plan.json")).fetch("files")).to eq(
          %w[spec/a_spec.rb spec/b_spec.rb],
        )
      end
    end
  end
end

RSpec.describe TestMappingDue do
  let(:now) { Time.utc(2026, 11, 1, 12) }
  let(:producer) do
    { "run" => { "id" => 42 }, "artifact" => { "created_at" => (now - 60).iso8601 } }
  end

  it "reuses both bundles from the latest successful producer within the interval" do
    TestMappingDownload.stubs(:latest).returns(producer)
    expect(described_class.due?(interval: 86_400, now: now)).to eq(false)
  end

  it "records again when the latest bundle has aged past the interval" do
    TestMappingDownload.stubs(:latest).returns(producer)
    expect(described_class.due?(interval: 30, now: now)).to eq(true)
  end

  it "records when a bundle is missing" do
    TestMappingDownload.stubs(:latest).with(workflow: "tests").returns(producer)
    TestMappingDownload.stubs(:latest).with(workflow: "migration-tests").returns(nil)
    expect(described_class.due?(interval: 86_400, now: now)).to eq(true)
  end

  it "records when the bundles come from different producer runs" do
    TestMappingDownload.stubs(:latest).with(workflow: "tests").returns(producer)
    TestMappingDownload
      .stubs(:latest)
      .with(workflow: "migration-tests")
      .returns(producer.merge("run" => { "id" => 43 }))
    expect(described_class.due?(interval: 86_400, now: now)).to eq(true)
  end
end

RSpec.describe TestMappingDownload do
  let(:repository) { "discourse/discourse" }
  let(:api) { "https://api.github.com" }
  let(:run) do
    {
      "id" => 42,
      "path" => ".github/workflows/test-mapping.yml",
      "event" => "push",
      "head_branch" => "main",
      "status" => "completed",
      "conclusion" => "success",
      "head_sha" => "b" * 40,
      "repository" => {
        "full_name" => repository,
      },
      "head_repository" => {
        "full_name" => repository,
      },
    }
  end

  before do
    ENV.stubs(:fetch).with("GITHUB_REPOSITORY").returns(repository)
    ENV.stubs(:fetch).with("GITHUB_API_URL", api).returns(api)
    stub_request(
      :get,
      "#{api}/repos/#{repository}/actions/artifacts?name=test-mapping-main-tests&per_page=20",
    ).to_return(
      body:
        JSON.generate(
          "artifacts" => [
            {
              "id" => 100,
              "expired" => false,
              "size_in_bytes" => 1000,
              "workflow_run" => {
                "id" => 42,
              },
            },
          ],
        ),
    )
  end

  it "accepts a completed successful main push from the mapping producer" do
    stub_request(:get, "#{api}/repos/#{repository}/actions/runs/42").to_return(
      body: JSON.generate(run),
    )
    expect(described_class.latest(workflow: "tests").fetch("run").fetch("id")).to eq(42)
  end

  it "rejects a producer from a pull request even when its artifact has the right name" do
    stub_request(:get, "#{api}/repos/#{repository}/actions/runs/42").to_return(
      body: JSON.generate(run.merge("event" => "pull_request")),
    )
    expect(described_class.latest(workflow: "tests")).to eq(nil)
  end

  it "rejects a failed producer with an uploaded artifact" do
    stub_request(:get, "#{api}/repos/#{repository}/actions/runs/42").to_return(
      body: JSON.generate(run.merge("conclusion" => "failure")),
    )
    expect(described_class.latest(workflow: "tests")).to eq(nil)
  end

  it "rejects artifacts whose producer used another repository" do
    stub_request(:get, "#{api}/repos/#{repository}/actions/runs/42").to_return(
      body: JSON.generate(run.merge("head_repository" => { "full_name" => "someone/discourse" })),
    )
    expect(described_class.latest(workflow: "tests")).to eq(nil)
  end

  describe ".fetch" do
    def mapping_archive(padding_bytes:)
      require "zip"
      prefix =
        JSON.generate(
          "version" => 3,
          "complete" => true,
          "revision" => run.fetch("head_sha"),
          "environment" => "core",
          "tests" => {
            "spec/consumer_spec.rb" => [],
          },
          "sources" => [],
          "source_checks" => {
          },
          "initialization_sources" => [],
          "shared_files" => [],
          "dependency_graph" => {
            "version" => 1,
            "paths" => [],
            "callers" => [],
          },
        ).delete_suffix("}") + ',"padding":"'
      digest = Digest::SHA256.new
      buffer =
        Zip::OutputStream.write_buffer do |archive|
          archive.put_next_entry("core-backend.json")
          archive.write(prefix)
          digest << prefix
          chunk = "x" * 65_536
          count, remainder = padding_bytes.divmod(chunk.bytesize)
          count.times do
            archive.write(chunk)
            digest << chunk
          end
          ending = chunk.byteslice(0, remainder) + '"}'
          archive.write(ending)
          digest << ending
        end
      { body: buffer.string, digest: digest.hexdigest }
    end

    before do
      ENV.stubs(:fetch).with("GITHUB_TOKEN").returns("fixture-token")
      stub_request(:get, "#{api}/repos/#{repository}/actions/runs/42").to_return(
        body: JSON.generate(run),
      )
    end

    it "recovers a mapping larger than the captured 275 MB core graph" do
      archive = mapping_archive(padding_bytes: 276_000_000)
      stub_request(:get, "#{api}/repos/#{repository}/actions/artifacts/100/zip").to_return(
        body: archive.fetch(:body),
      )

      Dir.mktmpdir do |directory|
        output = File.join(directory, "mappings")
        described_class.fetch(directory: output, workflow: "tests")

        expect(Digest::SHA256.file(File.join(output, "core-backend.json")).hexdigest).to eq(
          archive.fetch(:digest),
        )
      end
    end

    it "rejects an entry above 500 MB uncompressed before publishing mappings" do
      archive = mapping_archive(padding_bytes: 500_000_001)
      stub_request(:get, "#{api}/repos/#{repository}/actions/artifacts/100/zip").to_return(
        body: archive.fetch(:body),
      )

      Dir.mktmpdir do |directory|
        output = File.join(directory, "mappings")

        expect { described_class.fetch(directory: output, workflow: "tests") }.to raise_error(
          "Mapping entry exceeds size limit",
        )
        expect(File.exist?(output)).to eq(false)
      end
    end
  end
end
