# frozen_string_literal: true
require "json"
require "fileutils"
require "open3"
require_relative "../test_plan"
require_relative "../test_execution"
require_relative "../test_mapping"
require_relative "shared_state_scenarios"

module TestSelectionLab
  class SharedState
    def initialize(workspace:, source:, setup:, value:, name:, uncertain:)
      @workspace = workspace
      @source = source
      @setup = setup
      @value = value
      @name = name
      @uncertain = uncertain
    end

    def run
      root = File.join(@workspace, "tmp/proof/shared-state", @name)
      raise "Shared state workspace already exists" if File.exist?(root)
      FileUtils.mkdir_p(root)
      Dir.chdir(root) do
        write_fixture
        fixture =
          Dir["{lib,vendor,spec,plugins}/**/*.rb"].sort.to_h { |path| [path, File.read(path)] }
        File.write("tmp/fixture.json", JSON.pretty_generate(fixture))
        base = commit("Original shared fixture")
        baseline = catalog(base)
        ENV["COLLECT_TEST_MAPPING"] = "1"
        ENV["TEST_MAPPING_DIRECTORY"] = File.expand_path("tmp/raw")
        input =
          baseline.merge(
            "mode" => "full",
            "main" => true,
            "changes" => [],
            "test_changes" => [],
            "deleted_tests" => [],
          )
        File.write("tmp/main-plan.json", JSON.generate(TestSelection::Planner.new(input).plan))
        original = execute(plan: "tmp/main-plan.json", catalog: baseline, report: "tmp/main.json")
        raise "Original fixture failed" unless original.fetch("success")
        FileUtils.mkdir_p("tmp/mappings")
        TestMapping.merge(
          catalog: baseline,
          job_name: "plain",
          directory: ENV.fetch("TEST_MAPPING_DIRECTORY"),
          execution_directory: "tmp/main.json.workers",
          output: "tmp/mappings/plain.json",
        )
        ENV["COLLECT_TEST_MAPPING"] = "0"
        apply_change
        revision = commit("Change the fixture producer")
        current = catalog(revision)
        directory = File.join(@workspace, "tmp/proof/file-selection-lab/scenarios", @name)
        FileUtils.mkdir_p(directory)
        expected = %w[spec/1_writer_spec.rb spec/2_reader_spec.rb]
        expected << "spec/3_unrelated_spec.rb" if @uncertain
        fixture =
          {
            "context_scalar" => "a context fixture copied into a nested group",
            "let_scalar" => "a memoized fixture",
            "compact_let_scalar" =>
              "a memoized fixture whose declaration shares a line with its example",
            "context_helper_scalar" =>
              "a helper called by before(:context), whose fixture is copied into a nested group",
          }[
            @name
          ]
        why =
          if @name == "asynchronous_origin"
            "Writer starts a background task. Producer.value executes during the reader file. That execution has no attributable RSpec thread, so the full environment must remain eligible."
          elsif @name == "unobserved_branch"
            "The producer controls an unchanged branch whose cache write was never executed on main. Observed calls cannot establish its future effects, so every file remains eligible."
          elsif @name == "uncertain_outer_method"
            "The producer executes inside an unchanged application method with conditional control flow. Its nested dependencies require conservative protection, so changing the producer runs every file and retains the cache reader failure."
          elsif @name == "tracked_hash"
            "The writer updates a tracked hash and the reader uses a fixed symbol key with standard default behavior. The field connects both specs to the producer, while the third spec remains independent."
          elsif @name == "hash_default_proc"
            "This hash has a default procedure that a lookup can invoke. Its callback effects are not covered by the standard hash read rule, so the full environment remains eligible."
          elsif @name == "around_scalar"
            "The producer executes inside a multiline example wrapped by a support hook. That hook is not the producer's initialization context. The writer and cached reader run, while the unrelated third spec is omitted."
          elsif @name == "external_instance"
            "The writer stores the producer through an external client instance field. The reader consumes that field. The unrelated third file uses neither, so only writer and reader run."
          elsif @name == "file_store"
            "The producer changes bytes written through File.write. Its later reader never invokes the producer. This external store has no isolated test owner, so every file remains eligible."
          elsif @name == "dynamic_reflection"
            "The producer chooses a method through public_send. The baseline never invoked the new method, so its effects require every file to remain eligible."
          elsif @name == "dynamic_receiver"
            "The producer chooses which cache receives a write through a lookup. The baseline never called the other receiver. Its effects remain uncertain, so every file remains eligible."
          elsif @name == "array_receiver"
            "Changing the index from 0 to 1 redirects Array#at from the safe cache to the shared cache. The native lookup can choose a receiver absent from the baseline, so every file remains eligible."
          elsif @name.end_with?("random_state")
            "Changing the seed from 1234 to 5678 modifies process random state. The reader never calls the producer, but consumes its effect through Kernel.rand. This state has no isolated file owner, so every file remains eligible."
          elsif @name == "support_load_constant"
            "Changing the helper from 3 to 4 recomputes a constant while loading spec support. The reader only reads that constant. Its producing method must retain boot protection, so every file remains eligible."
          elsif @name == "environment_store"
            "The writer passes the producer value through process environment state. That store has no isolated test owner, so every file remains eligible."
          elsif @name.start_with?("control_")
            "The change alters control flow and enables a previously unexecuted cache write. The baseline mapping cannot describe that write, so every file remains eligible."
          elsif @name.start_with?("coarse_")
            "The producer writes a cache field and a later reader consumes it inside uncertain application control flow. Detailed nested tracing is suppressed there, so receiver state must remain protected even when collection places writer and reader in separate processes. Every file stays eligible."
          elsif @uncertain
            "The producer runs inside deferred fixture initialization with storage managed by the framework. This mapping cannot attribute the stored scalar to its later reader. Protecting that initialization requires every file in this environment."
          else
            "The writer stores the producer value through #{fixture}. The reader consumes that cache. Both must execute. The third spec is independent."
          end
        File.write(
          "#{directory}/expected.json",
          JSON.pretty_generate("files" => expected, "why" => why),
        )
        FileUtils.cp("tmp/fixture.json", "#{directory}/fixture.json")
        File.write("#{directory}/changes.diff", git("diff", "#{base}...#{revision}"))
        File.write("#{directory}/catalog.json", JSON.generate(current))
        arguments = {
          catalog_path: "#{directory}/catalog.json",
          mapping_directory: "tmp/mappings",
          base: base,
          revision: revision,
          main: false,
        }
        TestPlan.prepare(**arguments, output: "#{directory}/plan.json", mode: "select")
        plan = JSON.parse(File.read("#{directory}/plan.json"))
        selected =
          execute(
            plan: "#{directory}/plan.json",
            catalog: current,
            report: "#{directory}/selected.json",
          )
        TestPlan.prepare(**arguments, output: "#{directory}/audit.json", mode: "audit")
        full =
          execute(
            plan: "#{directory}/audit.json.reference.json",
            catalog: current,
            report: "#{directory}/full.json",
          )
        missed = full.fetch("failures") - selected.fetch("failures")
        complete =
          [selected, full].all? do |report|
            report.fetch("exact") && !report.fetch("non_example_failure") &&
              !report.fetch("unreported_failure")
          end
        correct =
          complete && plan.fetch("files") == expected && selected.fetch("loaded") == expected &&
            full.fetch("failures").any? && missed.empty?
        result = {
          "case" => @name,
          "base" => base,
          "revision" => revision,
          "expected" => expected,
          "selected" => plan.fetch("files"),
          "executed" => selected.fetch("loaded"),
          "selected_failures" => selected.fetch("failures"),
          "full_failures" => full.fetch("failures"),
          "missed_failures" => missed,
          "why" => why,
          "correct" => correct,
        }
        File.write("#{directory}/result.json", JSON.pretty_generate(result))
        puts JSON.generate(result)
        raise "Incorrect shared state selection: #{@name}" unless correct
      end
    ensure
      ENV["COLLECT_TEST_MAPPING"] = "0"
    end

    private

    def git(*arguments)
      output, status = Open3.capture2e("git", *arguments)
      raise output unless status.success?
      output.strip
    end

    def commit(message)
      git("add", ".")
      git("-c", "commit.gpgsign=false", "commit", "-qm", message)
      git("rev-parse", "HEAD")
    end

    def catalog(revision)
      command = %w[bundle exec rspec --options /dev/null --order defined]
      @producer_revision ||= revision
      if @name.start_with?("coarse_first_") && revision == @producer_revision
        command = [
          "bash",
          "-c",
          'bundle exec rspec --options /dev/null --order defined "$2" "$1" "$3"',
          "--",
        ]
      elsif @name.start_with?("coarse_split_") && revision == @producer_revision
        command = [
          "bash",
          "-c",
          'for file in "$@"; do bundle exec rspec --options /dev/null --order defined "$file" || exit; done',
          "--",
        ]
      end
      {
        "revision" => revision,
        "jobs" => {
          "plain" => {
            "environment" => "shared-state-proof",
            "runner" => "rspec",
            "command" => command,
            "inventory" => Dir["spec/*_spec.rb"].sort,
            "env" => {
            },
            "mapping_changes" => [],
            "verified_sources" => [],
          },
        },
      }
    end

    def execute(plan:, catalog:, report:)
      FileUtils.rm_f(%w[tmp/started tmp/signal tmp/completed tmp/shared.cache])
      ENV["GITHUB_SHA"] = catalog.fetch("revision")
      File.write("#{report}.catalog.json", JSON.generate(catalog))
      begin
        TestExecution.run(
          plan_path: plan,
          catalog_path: "#{report}.catalog.json",
          job_name: "plain",
          report_path: report,
        )
      rescue RuntimeError
        raise unless File.file?(report) && JSON.parse(File.read(report)).fetch("exact")
      end
      JSON.parse(File.read(report))
    end

    def write_fixture
      git("init", "-q")
      git("config", "user.name", "Shared state proof")
      git("config", "user.email", "selection@example.invalid")
      git("config", "core.hooksPath", "/dev/null")
      FileUtils.mkdir_p(%w[lib vendor spec tmp])
      File.symlink(File.join(@source, "script"), "script")
      File.write(".gitignore", "tmp/\nscript\nlog/\n")
      File.write(
        "vendor/cache.rb",
        "module SharedStateCache; def self.write(value); @value = value; end; def self.value; @value; end; end",
      )
      if @name == "external_instance"
        File.write(
          "vendor/cache.rb",
          "class ExternalCacheClient; def write(value); @value = value; end; def value; @value; end; end; SharedStateCache = ExternalCacheClient.new",
        )
      end
      File.write(
        "lib/producer.rb",
        "module SharedStateProducer; def self.value; :original; end; end",
      )
      bootstrap =
        if @setup.start_with?("fab!", "shared_fixture")
          "require 'test_prof/recipes/rspec/let_it_be'; TestProf::BeforeAll.adapter = TestProf::BeforeAll::NoopAdapter; TestProf::LetItBe.configure { |config| config.alias_to :fab!; config.alias_to :shared_fixture }"
        end
      File.write(
        "spec/helper.rb",
        "require_relative '../vendor/cache'\nrequire_relative '../lib/producer'\n#{bootstrap}\n",
      )
      File.write("spec/1_writer_spec.rb", <<~SPEC)
        require_relative 'helper'
        RSpec.describe 'Shared state writer' do
          #{@setup}
          context 'nested writer' do
            it('stores a value') { SharedStateCache.write(#{@value}); expect(SharedStateCache.value).to be_a(Symbol) }
          end
        end
      SPEC
      if @name == "compact_let_scalar"
        path = "spec/1_writer_spec.rb"
        File.write(path, File.read(path).gsub("\n", "; "))
      end
      File.write(
        "spec/2_reader_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Reader') { it('accepts an empty or original cache') { expect([nil, :original]).to include(SharedStateCache.value) } }",
      )
      File.write(
        "spec/3_unrelated_spec.rb",
        "RSpec.describe('Unrelated') { it('passes') { expect(true).to eq(true) } }",
      )
      write_asynchronous_fixture if @name == "asynchronous_origin"
      if %w[unobserved_branch dynamic_receiver dynamic_reflection].include?(@name) ||
           @name.start_with?("control_")
        write_control_fixture
      end
      write_environment_fixture if @name == "environment_store"
      write_file_fixture if @name == "file_store"
      write_array_receiver_fixture if @name == "array_receiver"
      write_random_fixture if @name.end_with?("random_state")
      write_load_helper_fixture if @name == "support_load_constant"
      if @name == "uncertain_outer_method"
        File.write(
          "lib/worker.rb",
          "module SharedStateWorker\n def self.populate(enabled)\n  SharedStateCache.write(SharedStateProducer.value) if enabled\n end\nend\n",
        )
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
        File.write(
          "spec/1_writer_spec.rb",
          "require_relative 'helper'\nRSpec.describe('Writer') { it('writes through conditional application code') { SharedStateWorker.populate(true) } }\n",
        )
      end
      if %w[tracked_hash hash_default_proc].include?(@name)
        initial = @name == "hash_default_proc" ? "Hash.new { nil }" : "{}"
        File.write(
          "lib/cache.rb",
          "module SharedStateCache\n @values = #{initial}\n def self.write(value)\n  @values[:key] = value\n end\n def self.value\n  @values[:key]\n end\nend\n",
        )
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/cache'" }
      end
      if @name.start_with?("coarse_")
        if @name.include?("owned")
          File.write("lib/cache.rb", File.read("vendor/cache.rb"))
          File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/cache'" }
        end
        body =
          (
            if @name.end_with?("conditional")
              "enabled = true; SharedStateCache.value if enabled"
            else
              "read { SharedStateCache.value }"
            end
          )
        File.write(
          "lib/reader.rb",
          "module SharedStateReader; def self.value; #{body}; end; def self.read; yield; end; end",
        )
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/reader'" }
        File.write(
          "spec/2_reader_spec.rb",
          "require_relative 'helper'\nRSpec.describe('Reader') { it('reads the cached value') { expect([nil, :original]).to include(SharedStateReader.value) } }",
        )
      end
      if @name == "around_scalar"
        FileUtils.mkdir_p("spec/support")
        File.write(
          "spec/support/runtime.rb",
          "RSpec.configure do |config|\n config.around(:each) do |example|\n  [1, 2].sum\n  example.run\n  [1, 2].sum\n end\nend\n",
        )
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative 'support/runtime'" }
        File.write(
          "spec/1_writer_spec.rb",
          "require_relative 'helper'\nRSpec.describe 'Writer' do\n it 'writes a scalar' do\n  SharedStateCache.write(SharedStateProducer.value)\n end\nend\n",
        )
      end
    end

    def apply_change
      if @name.end_with?("random_state")
        path = @name == "support_random_state" ? "spec/producer_helper.rb" : "lib/producer.rb"
        File.write(path, File.read(path).sub("1234", "5678"))
      elsif @name == "array_receiver"
        path = "lib/producer.rb"
        File.write(path, File.read(path).sub("  0\n", "  1\n"))
      elsif @name == "support_load_constant"
        path = "spec/limits.rb"
        File.write(path, File.read(path).sub("  3\n", "  4\n"))
      elsif @name.start_with?("control_")
        path = "lib/worker.rb"
        source = File.read(path)
        changed =
          case @name
          when "control_and"
            source.sub("false &&", "true &&")
          when "control_or"
            source.sub("true ||", "true &&")
          when "control_return"
            source.sub("return false;", "")
          end
        File.write(path, changed)
      else
        File.write("lib/producer.rb", File.read("lib/producer.rb").sub(":original", ":broken"))
      end
    end

    def write_control_fixture
      body =
        case @name
        when "dynamic_reflection"
          "public_send(SharedStateProducer.value)"
        when "dynamic_receiver"
          "{ original: SafeDispatchCache, broken: SharedStateCache }.fetch(SharedStateProducer.value).write(:broken)"
        when "unobserved_branch"
          "if SharedStateProducer.value == :broken; SharedStateCache.write(:broken); end"
        when "control_and"
          "false && SharedStateCache.write(:broken)"
        when "control_or"
          "true || SharedStateCache.write(:broken)"
        when "control_return"
          "return false; SharedStateCache.write(:broken)"
        end
      if %w[dynamic_receiver dynamic_reflection].include?(@name)
        File.open("vendor/cache.rb", "a") do |file|
          file.puts "\nmodule SafeDispatchCache; def self.write(value); @value = value; end; end"
        end
      end
      methods =
        if @name == "dynamic_reflection"
          "def self.original; SafeDispatchCache.write(:broken); end; def self.broken; SharedStateCache.write(:broken); end;"
        end
      File.write(
        "lib/worker.rb",
        "module SharedStateWorker; def self.populate; #{body}; end; #{methods} end",
      )
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('populates') { SharedStateWorker.populate } }\n",
      )
    end

    def write_literal_producer(path:, value:)
      File.write(path, "module SharedStateProducer\n def self.value\n  #{value}\n end\nend\n")
    end

    def write_array_receiver_fixture
      write_literal_producer(path: "lib/producer.rb", value: 0)
      File.open("vendor/cache.rb", "a") do |file|
        file.puts "\nmodule SafeDispatchCache; def self.write(value); @value = value; end; end"
      end
      File.write(
        "lib/worker.rb",
        "module SharedStateWorker; def self.populate; [SafeDispatchCache, SharedStateCache].at(SharedStateProducer.value).write(:broken); end; end",
      )
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('populates') { SharedStateWorker.populate } }\n",
      )
    end

    def write_random_fixture
      path = @name == "support_random_state" ? "spec/producer_helper.rb" : "lib/producer.rb"
      write_literal_producer(path: path, value: 1234)
      if @name == "support_random_state"
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative 'producer_helper'" }
      end
      if @name == "matcher_random_state"
        File.open("vendor/cache.rb", "a") do |file|
          file.puts "\nRSpec::Matchers.define(:seed_shared_rng) do\n match do |actual|\n  Kernel.srand(actual)\n  true\n end\nend\n"
        end
        action = "expect(SharedStateProducer.value).to seed_shared_rng"
      elsif @name.include?("external_random_state")
        api =
          case @name
          when "generated_external_random_state"
            "module ExternalRandom; end; ExternalRandom.module_eval('def self.seed(value); Kernel.srand(value); end')"
          when "block_external_random_state"
            "module ExternalRandom; define_singleton_method(:seed) { |value| Kernel.srand(value) }; end"
          else
            "module ExternalRandom; def self.seed(value); Kernel.srand(value); end; end"
          end
        if @name == "plugin_gem_external_random_state"
          gem = "plugins/poll/gems/#{RUBY_VERSION}/gems/seed-1.0.0/lib/seed.rb"
          FileUtils.mkdir_p(File.dirname(gem))
          File.write(gem, api)
          File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../#{gem}'" }
        else
          File.open("vendor/cache.rb", "a") { |file| file.puts "\n#{api}" }
        end
        action = "ExternalRandom.seed(SharedStateProducer.value)"
      else
        action = "Kernel.srand(SharedStateProducer.value)"
      end
      File.write(
        "lib/worker.rb",
        "module SharedStateWorker; def self.populate; #{action}; end; end",
      )
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
      writer =
        (
          if %w[
               direct_external_random_state
               block_external_random_state
               matcher_random_state
             ].include?(@name)
            action
          else
            "SharedStateWorker.populate"
          end
        )
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('seeds shared state') { #{writer} } }\n",
      )
      File.write(
        "spec/2_reader_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Reader') { it('reads shared state') { expect(Kernel.rand).to eq(Random.new(1234).rand) } }\n",
      )
    end

    def write_load_helper_fixture
      File.write(
        "spec/limits.rb",
        "module LoadTimeLimits\n def self.max\n  3\n end\n MAX = max\n def self.label\n  :unchanged\n end\nend\n",
      )
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative 'limits'" }
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('uses the helper') { expect(LoadTimeLimits.label).to eq(:unchanged) } }\n",
      )
      File.write(
        "spec/2_reader_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Reader') { it('reads the load time limit') { expect(LoadTimeLimits::MAX).to eq(3) } }\n",
      )
    end

    def write_file_fixture
      File.write(
        "lib/worker.rb",
        "module SharedStateWorker; def self.populate; File.write(File.expand_path('../tmp/shared.cache', __dir__), SharedStateProducer.value.to_s); end; end",
      )
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('stores bytes') { SharedStateWorker.populate } }\n",
      )
      File.write("spec/2_reader_spec.rb", <<~READER)
        require_relative 'helper'
        RSpec.describe 'Reader' do
          it 'reads the shared bytes' do
            path = File.expand_path('../tmp/shared.cache', __dir__)
            value = File.exist?(path) ? File.read(path) : nil
            expect([nil, 'original']).to include(value)
          end
        end
      READER
    end

    def write_environment_fixture
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Writer') { it('stores') { ENV['TEST_SELECTION_SHARED_VALUE'] = SharedStateProducer.value.to_s } }\n",
      )
      File.write(
        "spec/2_reader_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Reader') { it('reads') { expect([nil, 'original']).to include(ENV['TEST_SELECTION_SHARED_VALUE']) } }\n",
      )
    end

    def write_asynchronous_fixture
      File.write("lib/worker.rb", <<~WORKER)
        module SharedStateAsync
          STARTED = File.expand_path('../tmp/started', __dir__)
          SIGNAL = File.expand_path('../tmp/signal', __dir__)
          COMPLETED = File.expand_path('../tmp/completed', __dir__)
          def self.populate
            File.write(STARTED, 'ready')
            Thread.new do
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
              until File.exist?(SIGNAL)
                raise 'Signal timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
                sleep 0.001
              end
              SharedStateCache.write(SharedStateProducer.value)
              File.write(COMPLETED, 'ready')
            end
          end
        end
      WORKER
      File.open("spec/helper.rb", "a") { |file| file.puts "require_relative '../lib/worker'" }
      File.write(
        "spec/1_writer_spec.rb",
        "require_relative 'helper'\nRSpec.describe('Async writer') { it('starts work') { SharedStateAsync.populate } }\n",
      )
      File.write("spec/2_reader_spec.rb", <<~READER)
        require_relative 'helper'
        RSpec.describe 'Async reader' do
          it 'accepts an empty or original cache' do
            if File.exist?(SharedStateAsync::STARTED)
              File.write(SharedStateAsync::SIGNAL, 'ready')
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
              until File.exist?(SharedStateAsync::COMPLETED)
                raise 'Completion timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
                sleep 0.001
              end
            end
            expect([nil, :original]).to include(SharedStateCache.value)
          end
        end
      READER
    end
  end
end

workspace = Dir.pwd
workspace = File.expand_path(ARGV.first) if $PROGRAM_NAME == __FILE__ && ARGV.first
source = File.expand_path("../../..", __dir__)
scenarios = TestSelectionLab::SHARED_STATE_SCENARIOS
if $PROGRAM_NAME == __FILE__ && ARGV[1]
  scenarios = scenarios.select { |name, *_| name == ARGV[1] }
  raise ArgumentError, "Unknown shared state scenario: #{ARGV[1]}" if scenarios.empty?
end
scenarios.each do |name, setup, value, uncertain|
  TestSelectionLab::SharedState.new(
    workspace: workspace,
    source: source,
    setup: setup,
    value: value,
    name: name,
    uncertain: uncertain,
  ).run
end
