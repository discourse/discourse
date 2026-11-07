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
          (Dir["{lib,vendor,spec,plugins,docs}/**/*.rb"] + Dir["README.md", "docs/**/*.md"])
            .sort
            .to_h { |path| [path, File.read(path)] }
        File.write("tmp/fixture.json", JSON.pretty_generate(fixture))
        base = commit("Original shared fixture")
        mapping_revision = base
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
        if %w[
             mapping_lag_setup_spec
             mapping_lag_isolated_setup_spec
             mapping_lag_context_setup_spec
             file_size_documentation_history
           ].include?(@name) || documentation_history_case?
          if @name == "documentation_new_spec_history"
            File.write("spec/5_guide_spec.rb", <<~RUBY)
              RSpec.describe("Guide") do
                it("keeps its title") { expect(File.read("docs/guide.md")).to eq("Guide\\n") }
              end
            RUBY
          elsif @name == "documentation_source_history"
            File.write("lib/producer.rb", <<~RUBY)
              module SharedStateProducer
                def self.value
                  File.read("docs/guide.md") == "Guide\\n" ? :original : :changed
                end
              end
            RUBY
          elsif @name == "file_size_documentation_history"
            File.write("README.md", "hello world\n")
          elsif @name == "mapping_lag_context_setup_spec"
            path = "spec/1_writer_spec.rb"
            File.write(
              path,
              File.read(path).sub(
                "RSpec.describe 'Shared state writer' do",
                "RSpec.describe 'Shared state writer' do\n  before(:all) { ENV[\"FILE_PLAN_SHARED_SETUP\"] = SharedStateProducer.value.to_s }",
              ),
            )
          else
            File.open("spec/1_writer_spec.rb", "a") do |file|
              file.puts 'RSpec.configure { |config| config.before(:suite) { ENV["FILE_PLAN_SHARED_SETUP"] = SharedStateProducer.value.to_s } }'
            end
          end
          base = commit("Main adds shared setup after mapping collection")
          File.write("tmp/mapping-history.diff", git("diff", "#{mapping_revision}...#{base}"))
          fixture["spec/1_writer_spec.rb"] = File.read("spec/1_writer_spec.rb")
          if @name == "file_size_documentation_history"
            fixture["README.md"] = File.read("README.md")
          end
          if documentation_history_case?
            fixture["lib/producer.rb"] = File.read("lib/producer.rb")
            if @name == "documentation_new_spec_history"
              fixture["spec/5_guide_spec.rb"] = File.read("spec/5_guide_spec.rb")
            end
          end
          File.write("tmp/fixture.json", JSON.pretty_generate(fixture))
          control_catalog = catalog(base)
          control_input =
            control_catalog.merge(
              "mode" => "full",
              "main" => true,
              "changes" => [],
              "test_changes" => [],
              "deleted_tests" => [],
            )
          File.write(
            "tmp/new-main-plan.json",
            JSON.generate(TestSelection::Planner.new(control_input).plan),
          )
          control =
            execute(
              plan: "tmp/new-main-plan.json",
              catalog: control_catalog,
              report: "tmp/new-main.json",
            )
          raise "New main fixture failed" unless control.fetch("success")
        end
        apply_change
        revision = commit("Change the fixture producer")
        current = catalog(revision)
        directory = File.join(@workspace, "tmp/proof/file-selection-lab/scenarios", @name)
        FileUtils.mkdir_p(directory)
        expected = %w[spec/1_writer_spec.rb spec/2_reader_spec.rb]
        expected << "spec/3_unrelated_spec.rb" if @uncertain
        expected = ["spec/1_writer_spec.rb"] if @name == "file_metadata_predicate"
        if @name.start_with?("native_value_loop_native_")
          expected = %w[
            spec/1_writer_spec.rb
            spec/2_consumer_spec.rb
            spec/3_reader_spec.rb
            spec/4_unrelated_spec.rb
          ]
        end
        if @name.end_with?("_setup_spec") || metadata_subprocess_case? ||
             documentation_history_case?
          expected = current.fetch("jobs").fetch("plain").fetch("inventory")
        end
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
          if @name == "new_setup_spec"
            "The added file also registers global before suite setup. The existing reader consumes that changed setup, so the complete affected environment must run. A pure new spec remains a separate case."
          elsif @name == "changed_setup_spec"
            "The existing spec gains global before suite setup. Its reader can fail without running that spec's own examples, so this affects the complete environment."
          elsif @name == "removed_setup_spec"
            "The removed spec supplied global setup used by the reader. All remaining files in that environment must run, and the removed file must be omitted."
          elsif @name == "configuration_alias_setup_spec"
            "The changed callback uses the shared RSpec.configuration object. Its value controls the existing reader, so changing it requires the full affected environment."
          elsif %w[
                isolated_setup_spec
                isolated_configuration_setup_spec
                mapping_lag_isolated_setup_spec
                isolated_helper_setup_spec
                example_hook_setup_spec
                isolated_global_context_setup_spec
              ].include?(@name)
            "This historical subset expectation assumed that an unknown comparison or group helper could not affect another file. The selector has no ownership proof for those effects, so it protects the environment. The reader and independent third fixture pass in this particular reference. Their extra execution is a conservative efficiency limit, not evidence that every file depends on the edit."
          elsif @name == "literal_setup_spec"
            "The fixture string is inert. The added RSpec group still registers definitions that another file can inspect. Reader ownership is unknown, so the complete environment runs. The three existing files pass in this reference. Their extra execution is an efficiency limitation."
          elsif @name == "matcher_definition_setup_spec" || @name == "added_matcher_setup_spec"
            "A global matcher defined by a spec changes behavior for the existing reader. The writer or added spec passes, but the reader fails, so every file in this environment must remain eligible."
          elsif @name == "added_mocks_setup_spec"
            "The new spec enables global verification of partial doubles. The existing reader stubs an undefined method and now fails. This setting affects the whole environment."
          elsif @name == "captured_value_setup_spec"
            "A local value captured by an unchanged global setup hook changes. The reader observes that changed value, so the complete setup context must be protected."
          elsif @name == "provider_method_setup_spec" || @name == "included_helper_setup_spec"
            "A method defined outside the example groups supplies shared configuration or an included helper. The reader uses that method indirectly, so changing its body affects the whole environment."
          elsif @name == "environment_assignment_setup_spec"
            "Loading the changed spec writes process environment state consumed by an existing reader. No RSpec configuration call is needed for this shared effect."
          elsif @name == "shared_context_setup_spec"
            "A bare shared_context declaration at the top level changes a value included by another file. Its registration is global despite having no explicit RSpec receiver."
          elsif @name == "conditional_setup_spec"
            "An enclosing condition enables an unchanged global before suite hook. The reader changes from observing no setup to observing the new value, so the condition belongs to shared setup."
          elsif @name == "new_library_setup_spec"
            "The added spec loads an existing library that writes global environment state. The library was not loaded by the baseline. Running only the new spec would miss the existing reader failure."
          elsif @name == "removed_library_setup_spec"
            "The removed spec was the only file loading a library that initialized shared environment state. Its reader now fails because that initialization is absent. All remaining files stay eligible and the deleted file is omitted."
          elsif @name == "renamed_library_setup_spec"
            "Renaming the only library loader moves initialization after the reader file captures its setup value. The existing reader now fails, so running only the renamed destination would miss that failure."
          elsif @name == "mapping_lag_setup_spec"
            "Main added global setup after the mapping was recorded. The PR changes the producer used by that setup. The old mapping has no edge to the reader, so shared setup changes in mapping history require the full affected environment. Main itself passes before the PR mutation."
          elsif @name == "mapping_lag_context_setup_spec"
            "Main added a before all hook after mapping collection. The PR changes its producer. That context hook publishes process state to an unchanged reader, so the full affected environment must run despite the old mapping. Main control passes before the mutation."
          elsif %w[
                external_definition_setup_spec
                exported_helper_setup_spec
                invoked_class_helper_setup_spec
              ].include?(@name)
            "A definition inside the group supplies shared state directly, through an exported instance, or through setup that calls its helper. The unchanged reader consumes that definition and fails, so the whole environment must remain eligible."
          elsif %w[group_metadata_setup_spec description_argument_setup_spec].include?(@name)
            "Ruby evaluates group arguments while loading the file. The changed argument writes process state consumed by another file. Running only the writer would miss that reader failure."
          elsif @name == "context_hook_setup_spec"
            "The changed before all hook leaves process state for another file. Its scope outlives the individual example, so the unchanged reader must remain eligible."
          elsif @name == "terminal_assertion_setup_spec"
            "The unchanged teardown hook observes the changed assertion outcome and writes process state used by the existing reader. The writer and reader fail together. Unknown shared ownership protects the full environment, including the extra passing third fixture."
          elsif %w[
                frozen_context_setup_spec
                source_line_context_setup_spec
                metadata_line_context_setup_spec
                heredoc_context_setup_spec
              ].include?(@name)
            "The edited file changes a registered value through its compilation directive, source position or heredoc payload. The unchanged reader observes the change while the writer passes. Statement normalization would omit that reader, so the complete owning environment remains eligible, including the extra passing third fixture."
          elsif %w[
                matcher_override_setup_spec
                expectation_override_setup_spec
                custom_equality_setup_spec
              ].include?(@name)
            "An application comparison or expectation method writes the edited argument into shared process state. The writer still passes, but the existing reader fails. Unknown shared ownership protects the full environment, including the extra passing third fixture."
          elsif %w[
                registered_group_helper_setup_spec
                registered_group_let_setup_spec
                registered_group_subject_setup_spec
                registered_group_description_setup_spec
                registered_group_let_name_setup_spec
                registered_group_example_block_setup_spec
              ].include?(@name)
            "The existing reader locates the writer through the global RSpec group registry and calls its helper. The changed method value, method name, group identity or stored example block breaks that reader while the writer still passes. Unknown registry readers protect the full environment, including the extra passing third fixture."
          elsif @name == "metadata_included_let_setup_spec"
            "The metadata edit activates an included module that defines a memoized value. The unchanged writer publishes it to process state used by the reader. The writer passes and the reader fails, so the full affected environment remains eligible."
          elsif @name == "metadata_shared_context_setup_spec"
            "The shared context has metadata that RSpec uses to include it into a tagged reader in another file. Its location inside a group does not make this registration local."
          elsif %w[local_shared_examples_setup_spec literal_loop_setup_spec].include?(@name)
            "The changed example definition is registered in the RSpec world. A reader can inspect its stored block even when that block only returns a literal. Unknown registry ownership protects the complete environment. The reader and independent third fixture pass in this exact reference, so their extra execution is an efficiency limitation."
          elsif %w[
                autoload_argument_setup_spec
                namespaced_autoload_setup_spec
                constant_metadata_setup_spec
                constant_loop_setup_spec
              ].include?(@name)
            "Resolving the changed constant runs an existing autoload while the spec loads. Its library changes process state consumed by the unchanged reader, so that reader must remain eligible."
          elsif %w[fab_context_setup_spec fab_helper_setup_spec].include?(@name)
            "Discourse fab! runs once before the context. The changed block or its helper changes process state consumed by an unchanged reader, so this setup affects the whole environment."
          elsif %w[derived_metadata_setup_spec derived_description_setup_spec].include?(@name)
            "A literal declaration activates an existing metadata callback that changes process environment state. The writer passes, but the existing reader fails. Every file in this environment must run."
          elsif @name == "custom_equality_setup_spec"
            "The expected value reaches an application object's equality method, which writes process state. The comparison passes but the existing reader fails. Treating an unknown comparison as a pure assertion would omit that reader."
          elsif @name == "registered_group_helper_setup_spec"
            "RSpec exposes the group through its registry. An unchanged reader uses that group's helper, even though the helper only returns a literal. The writer passes and the reader fails after the helper changes, so group method definitions cannot be assumed private to their file."
          elsif @name == "assertion_before_write_setup_spec"
            "The changed assertion fails before an existing shared write. The unchanged reader therefore loses the original state and fails too. Selecting only the changed writer would omit that second failure."
          elsif %w[metadata_suite_hook_setup_spec metadata_included_helper_setup_spec].include?(
                @name,
              )
            "The metadata change activates an existing configured hook that writes shared process state. The writer passes but the unchanged reader fails, so the affected environment remains eligible."
          elsif %w[
                example_global_setup_spec
                example_helper_setup_spec
                example_cache_setup_spec
                helper_definition_setup_spec
              ].include?(@name)
            "The example or its helper writes shared process state consumed by the unchanged reader. The writer passes, but the reader fails. The collector cannot establish every consumer of that write, so the affected environment remains eligible."
          elsif @name == "example_environment_setup_spec"
            "The writer changes process environment state inside its example. That state survives the example and breaks the existing reader, so this body change requires the affected environment."
          elsif @name == "added_environment_hook_setup_spec"
            "The new file has a per example hook that changes process environment state. Its own example passes, but the existing reader fails afterward. The hook affects the owning environment."
          elsif @name == "metadata_environment_hook_setup_spec"
            "Literal metadata activates an existing filtered per example hook. The hook changes process environment state consumed by an unmatched reader, so changing the metadata affects the environment."
          elsif %w[isolated_constant_setup_spec isolated_fab_setup_spec].include?(@name)
            "The declaration registers a changed example definition. Another file can observe its assertion outcome or stored block through the RSpec registry. Unknown ownership protects the complete environment. The reader and independent third fixture pass in this exact reference, so their extra execution is an efficiency limitation."
          elsif @name == "asynchronous_origin"
            "Writer starts a background task. Producer.value executes during the reader file. That execution has no attributable RSpec thread, so the full environment must remain eligible."
          elsif @name == "unobserved_branch"
            "The producer controls an unchanged branch whose cache write was never executed on main. Observed calls cannot establish its future effects, so every file remains eligible."
          elsif @name == "uncertain_outer_method"
            "The producer executes inside an unchanged application method with conditional control flow. Its nested dependencies require conservative protection, so changing the producer runs every file and retains the cache reader failure."
          elsif @name == "tracked_hash"
            "The writer updates a tracked hash and the reader uses a fixed symbol key with standard default behavior. The field connects both specs to the producer, while the third spec remains independent."
          elsif @name == "hash_default_proc"
            "This hash has a default procedure that a lookup can invoke. Its callback effects are not covered by the standard hash read rule, so the full environment remains eligible."
          elsif @name.start_with?("native_value_loop_native_")
            "The first file stores the producer in an application native accessor. An external loop copies that scalar through the accessor, a Ruby callback or a Method object. These inputs do not establish builtin container dispatch, so native observation must retain the unchanged reader's dependency. The full environment remains eligible, including the independent fourth file."
          elsif @name.start_with?("native_value_loop_")
            "An external while loop stores the producer result using native array operations, directly or through a Ruby callback. Its inputs and cached receiver state protect the unchanged reader. The complete environment remains eligible, including the independent third file."
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
          elsif @name == "source_line_scalar"
            "A blank line in an earlier method shifts the producer's __LINE__ value. The writer passes while caching that changed integer. Source layout changes invalidate compatibility and protect the complete affected environment, retaining the unchanged failing reader. The unrelated third spec is a conservative extra execution."
          elsif @name == "source_line_initialization"
            "A blank line in an unused method shifts a later __LINE__ constant while its earlier reader method stays in place. The cached reader then fails. This changes protected initialization, so the complete affected environment must run."
          elsif source_line_layout_case?
            "A blank line in an unused method shifts source positions observed by initialization through a Ruby location API. The earlier value method stays unchanged, but the cached integer changes and its reader fails. Source layout changes invalidate compatibility and protect the complete affected environment. The unrelated third spec is a conservative extra execution."
          elsif metadata_subprocess_case?
            "The changed script runs in an untraced subprocess. An existence predicate does not establish a dependency on its content. Its effects remain unknown, so all four files must run, including the failing script reader. The three original files pass."
          elsif @name == "file_metadata_predicate"
            "Only an unused method comment changes. File.file? still reports true, so the initialized integer and cache stay unchanged. The existing loader dependency selects the writer. The reader and independent third file pass in the reference, and unchanged metadata does not require their execution."
          elsif @name == "documentation_new_spec_history"
            "Main adds a document reader after mapping collection. Its full control passes. The PR edits only that document. Mapping history must enter dependency selection. The old mapping cannot establish the new spec definitions' shared effects, so the complete owning environment must run, including the failing new reader."
          elsif @name == "documentation_source_history"
            "Main changes the producer to consume a document after mapping collection. Its full control passes. The PR edits only that document. Mapping history must enter dependency selection. The unverified source change protects the complete affected environment, including its failing cached reader."
          elsif @name == "file_size_documentation_history"
            "Main changes a mapped document so initialization reads a different document. Its full control still passes. The PR edits only that newly consumed document and now the cached reader fails. Changed shared inputs in mapping history must protect the owner even for a documentation only PR."
          elsif @name == "file_size_documentation"
            "The producer initializes its value from the size of README.md. Editing that document changes a scalar consumed by the unchanged reader. Observed metadata takes precedence over the usual documentation exclusion, so the complete affected environment runs."
          elsif file_metadata_case?
            "Lengthening an unused method comment changes the source file size read during initialization. The writer passes with the new integer while the unchanged cached reader fails. The observed filesystem input protects the complete affected environment."
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
        if File.file?("tmp/mapping-history.diff")
          FileUtils.cp("tmp/mapping-history.diff", "#{directory}/mapping-history.diff")
          FileUtils.cp("tmp/new-main.json", "#{directory}/main-control.json")
        end
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
            (
              if @name == "file_metadata_predicate"
                selected.fetch("success") && full.fetch("success")
              else
                full.fetch("failures").any?
              end
            ) && missed.empty?
        result = {
          "case" => @name,
          "base" => base,
          "mapping_revision" => mapping_revision,
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

    def documentation_history_case?
      %w[documentation_new_spec_history documentation_source_history].include?(@name)
    end

    def source_line_layout_case?
      @name.start_with?("source_line_") && !@name.end_with?("_setup_spec")
    end

    def file_metadata_case?
      %w[
        file_size_initialization
        file_test_size_initialization
        file_test_included_size_initialization
        file_test_extended_size_initialization
        file_custom_path_size_initialization
        file_string_path_size_initialization
        file_stat_initialization
        file_stat_constructor_initialization
        kernel_file_size_initialization
        kernel_module_file_size_initialization
        file_metadata_predicate
        file_size_documentation
        file_size_documentation_history
      ].include?(@name)
    end

    def metadata_subprocess_case?
      %w[
        file_metadata_subprocess
        file_metadata_subprocess_control
        file_metadata_document_subprocess
      ].include?(@name)
    end

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
      if documentation_history_case?
        FileUtils.mkdir_p("docs")
        File.write("docs/guide.md", "Guide\n")
      end
      if source_line_layout_case?
        producer =
          case @name
          when "source_line_scalar"
            "module SharedStateProducer\n def self.unrelated\n  :original\n  :unused\n end\n def self.value\n  __LINE__\n end\nend\n"
          when "source_line_method_metadata"
            "module SharedStateProducer\n def self.value\n  VALUE\n end\n def self.unrelated\n  :original\n  :unused\n end\n def self.marker\n  :marker\n end\n VALUE = method(:marker).source_location.last\nend\n"
          when "source_line_proc_metadata"
            "module SharedStateProducer\n def self.value\n  VALUE\n end\n def self.unrelated\n  :original\n  :unused\n end\n MARKER = -> {}\n VALUE = MARKER.source_location.last\nend\n"
          when "source_line_boot_caller"
            "module SharedStateProducer\n def self.value\n  VALUE\n end\n def self.capture\n  caller_locations(1, 1).first.lineno\n end\n def self.unrelated\n  :original\n  :unused\n end\n VALUE = capture\nend\n"
          else
            expression = {
              "source_line_initialization" => "__LINE__",
              "source_line_binding_initialization" => "binding.source_location.last",
              "source_line_caller_initialization" => "caller_locations(0, 1).first.lineno",
            }.fetch(@name)
            "module SharedStateProducer\n def self.value\n  VALUE\n end\n def self.unrelated\n  :original\n  :unused\n end\n VALUE = #{expression}\nend\n"
          end
        File.write("lib/producer.rb", producer)
        path = "spec/1_writer_spec.rb"
        File.write(path, File.read(path).sub("be_a(Symbol)", "be_a(Integer)"))
        path = "spec/2_reader_spec.rb"
        original_line =
          case @name
          when "source_line_scalar"
            7
          when "source_line_boot_caller"
            12
          else
            9
          end
        File.write(path, File.read(path).sub("[nil, :original]", "[nil, #{original_line}]"))
      end
      if file_metadata_case?
        expression = {
          "file_size_initialization" => "File.size(__FILE__)",
          "file_test_size_initialization" => "FileTest.size(__FILE__)",
          "file_test_included_size_initialization" => "MetadataInput.size_for(__FILE__)",
          "file_test_extended_size_initialization" => "MetadataInput.send(:size, __FILE__)",
          "file_custom_path_size_initialization" => "File.size(MetadataInput.new(__FILE__))",
          "file_string_path_size_initialization" => "File.size(MetadataInput.new(__FILE__))",
          "file_stat_initialization" => "File.stat(__FILE__).size",
          "file_stat_constructor_initialization" => "File::Stat.new(__FILE__).size",
          "kernel_file_size_initialization" => "test(?s, __FILE__)",
          "kernel_module_file_size_initialization" => "Kernel.test(?s, __FILE__)",
          "file_metadata_predicate" => "File.file?(__FILE__) ? 9 : 0",
          "file_size_documentation" => "File.size(File.expand_path(\"../README.md\", __dir__))",
          "file_size_documentation_history" =>
            'File.size(File.expand_path("../README.md", __dir__)) == 6 ? File.size(File.expand_path("../docs/a.md", __dir__)) : File.size(File.expand_path("../docs/b.md", __dir__))',
        }.fetch(@name)
        producer =
          "module SharedStateProducer\n def self.value\n  VALUE\n end\n def self.unrelated\n  :original # short\n  :unused\n end\n VALUE = #{expression}\nend\n"
        prefix =
          case @name
          when "file_test_included_size_initialization"
            "class MetadataInput\n include FileTest\n def self.size_for(path)\n  new.send(:size, path)\n end\nend\n"
          when "file_test_extended_size_initialization"
            "module MetadataInput\n extend FileTest\nend\n"
          when "file_custom_path_size_initialization"
            "class MetadataInput\n def initialize(path)\n  @path = path\n end\n def to_path\n  @path\n end\nend\n"
          when "file_string_path_size_initialization"
            "class MetadataInput\n def initialize(path)\n  @path = path\n end\n def to_str\n  @path\n end\nend\n"
          else
            ""
          end
        producer = prefix + producer
        File.write("lib/producer.rb", producer)
        if @name == "file_size_documentation"
          File.write("README.md", "Metadata fixture document.\n")
        elsif @name == "file_size_documentation_history"
          File.write("README.md", "hello\n")
          FileUtils.mkdir_p("docs")
          File.write("docs/a.md", "original")
          File.write("docs/b.md", "original")
        end
        original_value =
          case @name
          when "file_metadata_predicate"
            9
          when "file_size_documentation"
            File.size("README.md")
          when "file_size_documentation_history"
            8
          else
            producer.bytesize
          end
        path = "spec/1_writer_spec.rb"
        File.write(path, File.read(path).sub("be_a(Symbol)", "be_a(Integer)"))
        path = "spec/2_reader_spec.rb"
        File.write(path, File.read(path).sub("[nil, :original]", "[nil, #{original_value}]"))
      end
      if metadata_subprocess_case?
        script_path =
          @name == "file_metadata_document_subprocess" ? "docs/answer.rb" : "lib/answer.rb"
        FileUtils.mkdir_p(File.dirname(script_path))
        File.write(script_path, "def answer\n  41\nend\nputs answer\n")
        predicate =
          if @name == "file_metadata_subprocess_control"
            ""
          else
            "expect(File.file?(script)).to eq(true)\n    "
          end
        File.write("spec/4_script_spec.rb", <<~RUBY)
          require "rbconfig"
          RSpec.describe("Answer script") do
            it("prints 41") do
              script = File.expand_path("../#{script_path}", __dir__)
              #{predicate}output = IO.popen([{ "RUBYOPT" => nil, "BUNDLER_SETUP" => nil }, RbConfig.ruby, "--disable-gems", script], &:read)
              expect(output.strip).to eq("41")
            end
          end
        RUBY
      end
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
      if @name.start_with?("native_value_loop_")
        callback = @name.end_with?("callback", "_method")
        loop_value =
          if @name == "native_value_loop_native_accessor"
            "values[index].length"
          elsif callback
            "values[index][]"
          else
            "values[index]"
          end
        File.write("vendor/cache.rb", <<~RUBY)
          class NativeValueLoopCache
            def initialize
              @values = []
            end

            def write(value)
              enabled = true
              append([value]) if enabled
            end

            def append(values)
              index = 0
              while index < values.length
              @values << #{loop_value}
                index += 1
              end
            end

            def value
              @values[-1]
            end
          end
          SharedStateCache = NativeValueLoopCache.new
        RUBY
        value = callback ? "-> { SharedStateProducer.value }" : "SharedStateProducer.value"
        File.write("spec/1_writer_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Loop writer') do
            it('stores the original value') do
              SharedStateCache.write(#{value})
              expect(SharedStateCache.value).to eq(:original)
            end
          end
        RUBY
      end
      if @name.start_with?("native_value_loop_native_")
        accessor = @name == "native_value_loop_native_accessor" ? "length" : "value"
        File.write("lib/native_callback_cache.rb", <<~RUBY)
          module SharedStateNativeCache
            class << self
              attr_accessor :#{accessor}
            end
          end
        RUBY
        File.open("spec/helper.rb", "a") do |file|
          file.puts "require_relative '../lib/native_callback_cache'"
        end
        File.write("spec/1_writer_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Native cache writer') do
            it('stores the producer') do
              SharedStateNativeCache.#{accessor} = SharedStateProducer.value
              expect(SharedStateNativeCache.#{accessor}).to eq(:original)
            end
          end
        RUBY
        FileUtils.rm("spec/2_reader_spec.rb")
        FileUtils.rm("spec/3_unrelated_spec.rb")
        reader =
          case @name
          when "native_value_loop_native_accessor"
            "SharedStateNativeCache"
          when "native_value_loop_native_method"
            "SharedStateNativeCache.method(:value)"
          when "native_value_loop_native_vendor_method"
            "NativeReaderLookup.reader"
          else
            "-> { SharedStateNativeCache.value }"
          end
        if @name == "native_value_loop_native_vendor_method"
          File.open("vendor/cache.rb", "a") { |file| file.puts <<~RUBY }
              module NativeReaderLookup
                def self.reader
                  SharedStateNativeCache.method(:value)
                end
              end
            RUBY
        end
        File.write("spec/2_consumer_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Native callback consumer') do
            it('copies the cached scalar') do
              SharedStateCache.write(#{reader})
              expect(SharedStateCache.value).to be_a(Symbol)
            end
          end
        RUBY
        File.write("spec/3_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Callback cache reader') do
            it('retains the original scalar') { expect(SharedStateCache.value).to eq(:original) }
          end
        RUBY
        File.write(
          "spec/4_unrelated_spec.rb",
          "RSpec.describe('Independent') { it('passes') { expect(true).to eq(true) } }",
        )
      end
      if @name == "around_scalar"
        FileUtils.mkdir_p("spec/support")
        File.write("spec/support/runtime.rb", <<~RUBY)
            require "timeout"
            RSpec.configure do |config|
              config.around(:each) do |example|
                count = [1, 2].sum
                Timeout.timeout(30) { example.run }
                expect([1, 2].sum).to eq(count)
              end
            end
          RUBY
        File.open("spec/helper.rb", "a") { |file| file.puts "require_relative 'support/runtime'" }
        File.write(
          "spec/1_writer_spec.rb",
          "require_relative 'helper'\nRSpec.describe 'Writer' do\n it 'writes a scalar' do\n  SharedStateCache.write(SharedStateProducer.value)\n  expect(SharedStateCache.value.equal?(:original)).to eq(true)\n end\nend\n",
        )
      end
      write_test_setup_fixture if @name.end_with?("_setup_spec")
    end

    def apply_change
      if documentation_history_case?
        File.write("docs/guide.md", "Changed guide\n")
      elsif source_line_layout_case?
        path = "lib/producer.rb"
        File.write(path, File.read(path).sub(":original\n  :unused", ":original\n\n  :unused"))
      elsif @name == "file_size_documentation"
        File.open("README.md", "a") { |file| file.puts "Extra documentation." }
      elsif @name == "file_size_documentation_history"
        File.write("docs/b.md", "changed size")
      elsif file_metadata_case?
        path = "lib/producer.rb"
        File.write(path, File.read(path).sub("# short", "# a longer comment"))
      elsif metadata_subprocess_case?
        path = @name == "file_metadata_document_subprocess" ? "docs/answer.rb" : "lib/answer.rb"
        File.write(path, File.read(path).sub("  41\n", "  42\n"))
      elsif @name.end_with?("_setup_spec")
        apply_test_setup_change
      elsif @name.end_with?("random_state")
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

    def write_initialization_fixture
      if @name == "metadata_included_let_setup_spec"
        File.open("spec/helper.rb", "a") { |file| file.puts <<~RUBY }
            module SharedProcessLet
              def self.included(group)
                group.let(:shared_setup_value) { "changed" }
              end
            end
            RSpec.configure { |config| config.include SharedProcessLet, shared_process_state: true }
          RUBY
      end
      if %w[metadata_suite_hook_setup_spec metadata_included_helper_setup_spec].include?(@name)
        File.open("spec/helper.rb", "a") do |file|
          file.puts 'ENV["FILE_PLAN_SHARED_SETUP"] = "original"'
          if @name == "metadata_suite_hook_setup_spec"
            file.puts <<~RUBY
              RSpec.configure do |config|
                config.before(:suite) do
                  if RSpec.world.all_examples.any? { |example| example.metadata[:shared_process_state] }
                    ENV["FILE_PLAN_SHARED_SETUP"] = "changed"
                  end
                end
              end
            RUBY
          else
            file.puts <<~RUBY
              module SharedProcessHook
                def write_shared_process_setting
                  ENV["FILE_PLAN_SHARED_SETUP"] = "changed"
                end
                def self.included(group)
                  group.before(:each) { write_shared_process_setting }
                end
              end
              RSpec.configure { |config| config.include SharedProcessHook, shared_process_state: true }
            RUBY
          end
        end
      end
      if %w[
           autoload_argument_setup_spec
           namespaced_autoload_setup_spec
           constant_metadata_setup_spec
           constant_loop_setup_spec
           isolated_constant_setup_spec
         ].include?(@name)
        %w[Original Changed].each do |name|
          File.write(
            "lib/autoload_#{name.downcase}.rb",
            "ENV[\"FILE_PLAN_SHARED_SETUP\"] = #{name.downcase.inspect}\nclass FilePlan#{name}; end\n",
          )
          File.write(
            "lib/namespaced_#{name.downcase}.rb",
            "ENV[\"FILE_PLAN_SHARED_SETUP\"] = #{name.downcase.inspect}\nmodule FilePlanAutoload; class #{name}; end; end\n",
          )
        end
        helper = "spec/helper.rb"
        unless File.read(helper).include?("autoload :FilePlanOriginal")
          File.open(helper, "a") { |file| file.puts <<~RUBY }
              autoload :FilePlanOriginal, File.expand_path('../lib/autoload_original.rb', __dir__)
              autoload :FilePlanChanged, File.expand_path('../lib/autoload_changed.rb', __dir__)
              module FilePlanAutoload
                autoload :Original, File.expand_path('../lib/namespaced_original.rb', __dir__)
                autoload :Changed, File.expand_path('../lib/namespaced_changed.rb', __dir__)
              end
            RUBY
        end
      elsif %w[fab_context_setup_spec fab_helper_setup_spec isolated_fab_setup_spec].include?(@name)
        File.open("spec/helper.rb", "a") do |file|
          file.puts "require 'test_prof/recipes/rspec/let_it_be'; TestProf::BeforeAll.adapter = TestProf::BeforeAll::NoopAdapter; TestProf::LetItBe.configure { |config| config.alias_to :fab! }"
        end
      elsif @name == "isolated_global_context_setup_spec"
        File.open("spec/helper.rb", "a") do |file|
          file.puts 'shared_context("Shared writer context") { let(:writer_value) { "original" } }'
        end
      end
    end

    def initialization_setup_source(value:)
      literal = value.inspect
      if %w[
           autoload_argument_setup_spec
           namespaced_autoload_setup_spec
           constant_metadata_setup_spec
           constant_loop_setup_spec
           isolated_constant_setup_spec
         ].include?(@name)
        constant = value == "original" ? "FilePlanOriginal" : "FilePlanChanged"
        body =
          case @name
          when "namespaced_autoload_setup_spec"
            "RSpec.describe FilePlanAutoload::#{value.capitalize} do\n  it('passes independently') { expect(true).to eq(true) }\nend\n"
          when "constant_metadata_setup_spec"
            "RSpec.describe 'Constant metadata' do\n  it('passes independently', file_plan_setup: #{constant}) { expect(true).to eq(true) }\nend\n"
          when "constant_loop_setup_spec"
            "RSpec.describe 'Constant loop' do\n  [#{constant}].each do |klass|\n    it('passes independently') { expect(klass).to be_a(Class) }\n  end\nend\n"
          when "isolated_constant_setup_spec"
            "RSpec.describe FilePlanOriginal do\n  it('checks its own value') { expect(#{literal}).to eq(\"original\") }\nend\n"
          else
            "RSpec.describe #{constant} do\n  it('passes independently') { expect(true).to eq(true) }\nend\n"
          end
      elsif %w[fab_context_setup_spec fab_helper_setup_spec isolated_fab_setup_spec].include?(@name)
        setup = @name == "isolated_fab_setup_spec" ? '"original"' : literal
        definition =
          @name == "fab_helper_setup_spec" ? "def shared_setup_value\n  #{literal}\nend\n" : ""
        setup = "shared_setup_value" if @name == "fab_helper_setup_spec"
        expectation =
          (
            if @name == "isolated_fab_setup_spec"
              "expect(#{literal}).to eq(\"original\")"
            else
              "expect(shared_setup_record).to be_a(Object)"
            end
          )
        body = <<~RUBY
          RSpec.describe 'Prefabricated setup' do
            #{definition}
            fab!(:shared_setup_record) do
              ENV["FILE_PLAN_SHARED_SETUP"] = #{setup}
              Object.new
            end
            it('checks its own value') { #{expectation} }
          end
        RUBY
      elsif @name == "example_hook_setup_spec"
        body = <<~RUBY
          RSpec.describe 'Example scope hook' do
            before(:example) { @value = "original" }
            it('checks its own value') { expect(@value).to eq(#{literal}) }
          end
        RUBY
      elsif @name == "isolated_global_context_setup_spec"
        body = <<~RUBY
          RSpec.describe 'Global inclusion owner' do
            include_context 'Shared writer context'
            it('checks its own value') { expect(writer_value).to eq(#{literal}) }
          end
        RUBY
      end
      "require_relative 'helper'\n#{body}" if body
    end

    def group_setup_source(value:)
      return <<~RUBY if @name == "frozen_context_setup_spec"
          # frozen_string_literal: #{value == "changed"}
          require_relative 'helper'
          RSpec.describe('Registered frozen writer') do
            let(:shared_setup_value) { "original" }
            it('passes independently') { expect(true).to eq(true) }
          end
        RUBY
      if %w[source_line_context_setup_spec metadata_line_context_setup_spec].include?(@name)
        source = <<~RUBY
          require_relative 'helper'
          RSpec.describe('Registered line writer') do
            let(:shared_setup_value) { __LINE__ }
            it('passes independently') { expect(true).to eq(true) }
          end
        RUBY
        return value == "changed" ? "\n#{source}" : source
      end
      return <<~RUBY if @name == "heredoc_context_setup_spec"
          require_relative 'helper'
          FilePlanHeredocValue = <<~VALUE
            #{value}
          VALUE
          RSpec.describe('Heredoc writer') do
            it('publishes the value') { ENV["FILE_PLAN_SHARED_SETUP"] = FilePlanHeredocValue.chomp }
          end
        RUBY
      source = initialization_setup_source(value: value)
      return source if source
      literal = value.inspect
      body =
        case @name
        when "terminal_assertion_setup_spec"
          <<~RUBY
            RSpec.describe('Assertion observed by teardown') do
              after(:each) do |example|
                ENV["FILE_PLAN_SHARED_SETUP"] = example.exception ? "changed" : "original"
              end
              it('checks a primitive') { expect(true).to eq(#{value == "original"}) }
            end
          RUBY
        when "matcher_override_setup_spec"
          <<~RUBY
            RSpec.describe('Matcher override writer') do
              def eq(expected)
                ENV["FILE_PLAN_SHARED_SETUP"] = expected
                super(true)
              end
              it('compares a literal') { expect(true).to eq(#{literal}) }
            end
          RUBY
        when "expectation_override_setup_spec"
          <<~RUBY
            RSpec.describe('Expectation override writer') do
              def expect(actual)
                ENV["FILE_PLAN_SHARED_SETUP"] = actual
                super(true)
              end
              it('compares a literal') { expect(#{literal}).to eq(true) }
            end
          RUBY
        when "registered_group_example_block_setup_spec"
          <<~RUBY
            RSpec.describe('Registered example writer') do
              it('returns a value') { #{literal} }
            end
          RUBY
        when "registered_group_let_setup_spec", "registered_group_subject_setup_spec"
          declaration = @name == "registered_group_let_setup_spec" ? "let" : "subject"
          <<~RUBY
            RSpec.describe('Registered helper writer') do
              #{declaration}(:shared_setup_value) { #{literal} }
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "registered_group_let_name_setup_spec"
          name = value == "original" ? "shared_setup_value" : "renamed_setup_value"
          <<~RUBY
            RSpec.describe('Registered helper writer') do
              let(:#{name}) { "original" }
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "registered_group_description_setup_spec"
          <<~RUBY
            RSpec.describe(#{literal}) do
              def shared_setup_value
                "original"
              end
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "metadata_included_let_setup_spec"
          <<~RUBY
            RSpec.describe('Metadata writer', shared_process_state: #{value == "changed"}) do
              it('publishes the memoized value') do
                ENV["FILE_PLAN_SHARED_SETUP"] = respond_to?(:shared_setup_value) ? shared_setup_value : "original"
              end
            end
          RUBY
        when "assertion_before_write_setup_spec"
          <<~RUBY
            RSpec.describe('Assertion before writer') do
              it('checks before writing') do
                expect(true).to eq(#{value == "original"})
                ENV["FILE_PLAN_SHARED_SETUP"] = "original"
              end
            end
          RUBY
        when "metadata_suite_hook_setup_spec", "metadata_included_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Metadata writer', shared_process_state: #{value == "changed"}) do
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "custom_equality_setup_spec"
          <<~RUBY
            RSpec.describe('Comparison writer') do
              class FilePlanSharedEquality
                def ==(expected)
                  ENV["FILE_PLAN_SHARED_SETUP"] = expected
                  true
                end
              end
              it('compares an application value') { expect(FilePlanSharedEquality.new).to eq(#{literal}) }
            end
          RUBY
        when "registered_group_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Registered helper writer') do
              def shared_setup_value
                #{literal}
              end
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "example_global_setup_spec"
          <<~RUBY
            RSpec.describe('Global writer') do
              it('writes process state') { $file_plan_shared_process_state = #{literal} }
            end
          RUBY
        when "example_cache_setup_spec"
          <<~RUBY
            RSpec.describe('Cache writer') do
              it('writes shared state') { SharedStateCache.write(#{literal}) }
            end
          RUBY
        when "example_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Helper invocation writer') do
              def write_process_setting(value)
                ENV["FILE_PLAN_SHARED_SETUP"] = value
              end
              it('writes process state') { write_process_setting(#{literal}) }
            end
          RUBY
        when "helper_definition_setup_spec"
          <<~RUBY
            RSpec.describe('Helper definition writer') do
              def write_process_setting
                ENV["FILE_PLAN_SHARED_SETUP"] = #{literal}
              end
              it('writes process state') { write_process_setting }
            end
          RUBY
        when "external_definition_setup_spec"
          <<~RUBY
            RSpec.describe('Shared singleton setup') do
              def SharedStateCache.shared_setup_value
                #{literal}
              end
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "exported_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Exported helper setup') do
              def shared_setup_value
                #{literal}
              end
              SharedStateCache.instance_variable_set(:@setup_helper, new)
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "invoked_class_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Invoked helper setup') do
              def self.shared_setup_value
                #{literal}
              end
              ENV["FILE_PLAN_SHARED_SETUP"] = shared_setup_value
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "group_metadata_setup_spec"
          <<~RUBY
            RSpec.describe('Metadata setup', file_plan_setup: (ENV["FILE_PLAN_SHARED_SETUP"] = #{literal})) do
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "description_argument_setup_spec"
          <<~RUBY
            def file_plan_description(value)
              ENV["FILE_PLAN_SHARED_SETUP"] = value
              "Description setup"
            end
            RSpec.describe(file_plan_description(#{literal})) do
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "context_hook_setup_spec"
          <<~RUBY
            RSpec.describe('Context setup') do
              before(:all) { ENV["FILE_PLAN_SHARED_SETUP"] = #{literal} }
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "local_shared_examples_setup_spec"
          <<~RUBY
            RSpec.describe('Local shared definitions') do
              shared_examples('Scoped assertion') do
                it('checks its own value') { expect("original").to eq(#{literal}) }
              end
              it_behaves_like 'Scoped assertion'
            end
          RUBY
        when "metadata_shared_context_setup_spec"
          <<~RUBY
            RSpec.describe('Metadata sharing') do
              shared_context('Tagged setup', file_plan_shared: true) do
                let(:shared_setup_value) { #{literal} }
              end
              it('passes independently') { expect(true).to eq(true) }
            end
          RUBY
        when "literal_loop_setup_spec"
          <<~RUBY
            RSpec.describe('Literal example generation') do
              [false, true].each do |flag|
                it('checks its own value') { expect("original").to eq(#{literal}) }
              end
            end
          RUBY
        when "isolated_helper_setup_spec"
          <<~RUBY
            RSpec.describe('Scoped helper') do
              def shared_setup_value
                #{literal}
              end
              it('checks its own value') { expect(shared_setup_value).to eq("original") }
            end
          RUBY
        end
      "require_relative 'helper'\n#{body}" if body
    end

    def write_group_setup_fixture(source)
      File.write("spec/1_writer_spec.rb", source)
      expression =
        case @name
        when "frozen_context_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "Registered frozen writer" }.new.shared_setup_value.frozen? ? "changed" : "original"'
        when "source_line_context_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "Registered line writer" }.new.shared_setup_value == 3 ? "original" : "changed"'
        when "metadata_line_context_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "Registered line writer" }.metadata[:line_number] == 2 ? "original" : "changed"'
        when "registered_group_helper_setup_spec", "registered_group_let_setup_spec",
             "registered_group_subject_setup_spec", "registered_group_let_name_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "Registered helper writer" }.new.shared_setup_value'
        when "registered_group_example_block_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "Registered example writer" }.examples.first.instance_variable_get(:@example_block).call'
        when "registered_group_description_setup_spec"
          'RSpec.world.example_groups.find { |group| group.description == "original" }.new.shared_setup_value'
        when "example_global_setup_spec"
          "$file_plan_shared_process_state"
        when "example_cache_setup_spec"
          "SharedStateCache.value"
        when "external_definition_setup_spec"
          "SharedStateCache.shared_setup_value"
        when "exported_helper_setup_spec"
          "SharedStateCache.instance_variable_get(:@setup_helper).shared_setup_value"
        when "metadata_shared_context_setup_spec"
          "shared_setup_value"
        when "local_shared_examples_setup_spec", "literal_loop_setup_spec",
             "isolated_helper_setup_spec", "example_hook_setup_spec",
             "isolated_global_context_setup_spec"
          '"original"'
        else
          'ENV["FILE_PLAN_SHARED_SETUP"]'
        end
      metadata = @name == "metadata_shared_context_setup_spec" ? ", file_plan_shared: true" : ""
      File.write("spec/2_reader_spec.rb", <<~RUBY)
        require_relative 'helper'
        RSpec.describe('Existing setup reader'#{metadata}) do
          it('keeps the original value') { expect(#{expression}).to eq("original") }
        end
      RUBY
    end

    def test_setup_hook(value:)
      case @name
      when "configuration_alias_setup_spec", "isolated_configuration_setup_spec"
        "RSpec.configuration.before(:suite) { ENV[\"FILE_PLAN_SHARED_SETUP\"] = #{value.inspect} }\n"
      when "captured_value_setup_spec"
        <<~RUBY
          setup_value = #{value.inspect}
          RSpec.configure { |config| config.before(:suite) { ENV["FILE_PLAN_SHARED_SETUP"] = setup_value } }
        RUBY
      when "provider_method_setup_spec"
        <<~RUBY
          module FilePlanSharedSetup
            def self.value
              #{value.inspect}
            end
          end
          RSpec.configure { |config| config.before(:suite) { ENV["FILE_PLAN_SHARED_SETUP"] = FilePlanSharedSetup.value } }
        RUBY
      when "included_helper_setup_spec"
        <<~RUBY
          module FilePlanSharedHelpers
            def shared_setup_value
              #{value.inspect}
            end
          end
          RSpec.configure { |config| config.include FilePlanSharedHelpers }
        RUBY
      when "environment_assignment_setup_spec"
        "ENV[\"FILE_PLAN_SHARED_SETUP\"] = #{value.inspect}\n"
      when "conditional_setup_spec"
        <<~RUBY
          if #{value == "changed"}
            RSpec.configure { |config| config.before(:suite) { ENV["FILE_PLAN_SHARED_SETUP"] = "changed" } }
          end
        RUBY
      when "matcher_definition_setup_spec", "added_matcher_setup_spec"
        "RSpec::Matchers.define(:match_shared_setup) { match { |actual| actual == #{value.inspect} } }\n"
      when "shared_context_setup_spec"
        "shared_context('File plan shared setup') { let(:shared_setup_value) { #{value.inspect} } }\n"
      when "removed_library_setup_spec", "renamed_library_setup_spec"
        "require_relative '../lib/extra_setup'\n"
      else
        <<~RUBY
          RSpec.configure do |configuration|
            configuration.before(:suite) { ENV["FILE_PLAN_SHARED_SETUP"] = #{value.inspect} }
          end
        RUBY
      end
    end

    def write_test_setup_fixture
      write_initialization_fixture
      if %w[
           example_environment_setup_spec
           added_environment_hook_setup_spec
           metadata_environment_hook_setup_spec
         ].include?(@name)
        File.open("spec/helper.rb", "a") do |file|
          file.puts 'ENV["FILE_PLAN_SCOPED_STATE"] = "original"'
          file.puts <<~RUBY if @name == "metadata_environment_hook_setup_spec"
              RSpec.configure do |config|
                config.before(:each, scoped_state: true) { ENV["FILE_PLAN_SCOPED_STATE"] = "changed" }
              end
            RUBY
        end
        metadata = @name == "metadata_environment_hook_setup_spec" ? ", scoped_state: false" : ""
        assignment =
          (
            if @name == "example_environment_setup_spec"
              'ENV["FILE_PLAN_SCOPED_STATE"] = "original"'
            else
              ""
            end
          )
        File.write("spec/1_writer_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe("Scoped writer"#{metadata}) do
            it('passes independently') { #{assignment}; expect(true).to eq(true) }
          end
        RUBY
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe("Existing process state reader") do
            it('sees original process state') { expect(ENV["FILE_PLAN_SCOPED_STATE"]).to eq("original") }
          end
        RUBY
        return
      end
      if %w[derived_metadata_setup_spec derived_description_setup_spec].include?(@name)
        filter =
          (
            if @name == "derived_metadata_setup_spec"
              'file_plan_setup: "changed"'
            else
              'description: "Changed group"'
            end
          )
        File.open("spec/helper.rb", "a") { |file| file.puts <<~RUBY }
            ENV["FILE_PLAN_SHARED_SETUP"] = "original"
            RSpec.configure do |config|
              config.define_derived_metadata(#{filter}) do |metadata|
                ENV["FILE_PLAN_SHARED_SETUP"] = "changed"
              end
            end
          RUBY
        argument =
          (
            if @name == "derived_metadata_setup_spec"
              '"Writer", file_plan_setup: "original"'
            else
              '"Original group"'
            end
          )
        File.write("spec/1_writer_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe(#{argument}) do
            it('passes independently') { expect(true).to eq(true) }
          end
        RUBY
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Existing reader') do
            it('keeps original state') { expect(ENV["FILE_PLAN_SHARED_SETUP"]).to eq("original") }
          end
        RUBY
        return
      end
      if source = group_setup_source(value: "original")
        write_group_setup_fixture(source)
        return
      end
      configured = %w[
        removed_setup_spec
        isolated_setup_spec
        configuration_alias_setup_spec
        isolated_configuration_setup_spec
        captured_value_setup_spec
        provider_method_setup_spec
        included_helper_setup_spec
        environment_assignment_setup_spec
        conditional_setup_spec
        matcher_definition_setup_spec
        shared_context_setup_spec
        removed_library_setup_spec
        renamed_library_setup_spec
      ].include?(@name)
      if configured
        File.open("spec/1_writer_spec.rb", "a") do |file|
          file.puts test_setup_hook(value: "original")
        end
      end
      expected = configured && @name != "conditional_setup_spec" ? '"original"' : "nil"
      File.write("spec/2_reader_spec.rb", <<~RUBY)
        require_relative 'helper'
        RSpec.describe('Setup reader') do
          it('uses the original shared setup') { expect(ENV["FILE_PLAN_SHARED_SETUP"]).to eq(#{expected}) }
        end
      RUBY
      if @name == "added_matcher_setup_spec"
        File.open("spec/helper.rb", "a") { |file| file.puts test_setup_hook(value: "original") }
      end
      if %w[matcher_definition_setup_spec added_matcher_setup_spec].include?(@name)
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Matcher reader') { it('uses the shared matcher') { expect("original").to match_shared_setup } }
        RUBY
      elsif @name == "included_helper_setup_spec"
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Included helper reader') { it('uses the shared helper') { expect(shared_setup_value).to eq("original") } }
        RUBY
      elsif @name == "shared_context_setup_spec"
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Shared context reader') do
            include_context 'File plan shared setup'
            it('uses the shared context') { expect(shared_setup_value).to eq("original") }
          end
        RUBY
      elsif @name == "added_mocks_setup_spec"
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Mock reader') do
            it('stubs an undefined method') do
              allow(SharedStateCache).to receive(:undefined_shared_method).and_return(1)
              expect(SharedStateCache.undefined_shared_method).to eq(1)
            end
          end
        RUBY
      elsif @name == "new_library_setup_spec"
        File.write("lib/extra_setup.rb", "ENV[\"FILE_PLAN_SHARED_SETUP\"] = \"changed\"\n")
      elsif %w[removed_library_setup_spec renamed_library_setup_spec].include?(@name)
        File.write("lib/extra_setup.rb", "ENV[\"FILE_PLAN_SHARED_SETUP\"] = \"original\"\n")
        File.write("spec/2_reader_spec.rb", <<~RUBY) if @name == "renamed_library_setup_spec"
            require_relative 'helper'
            setup_seen = ENV["FILE_PLAN_SHARED_SETUP"]
            RSpec.describe('Setup order reader') { it('captures initialized state') { expect(setup_seen).to eq("original") } }
          RUBY
      elsif %w[
            mapping_lag_setup_spec
            mapping_lag_isolated_setup_spec
            mapping_lag_context_setup_spec
          ].include?(@name)
        File.write("lib/producer.rb", <<~RUBY)
          module SharedStateProducer
            def self.value
              :original
            end
          end
        RUBY
        File.write("spec/2_reader_spec.rb", <<~RUBY)
          require_relative 'helper'
          RSpec.describe('Mapping history reader') do
            it('accepts original shared setup') { expect([nil, "original"]).to include(ENV["FILE_PLAN_SHARED_SETUP"]) }
          end
        RUBY
      end
    end

    def apply_test_setup_change
      if source = group_setup_source(value: "changed")
        File.write("spec/1_writer_spec.rb", source)
        return
      end
      case @name
      when "example_environment_setup_spec", "metadata_environment_hook_setup_spec"
        path = "spec/1_writer_spec.rb"
        before, after =
          (
            if @name == "example_environment_setup_spec"
              ['= "original"', '= "changed"']
            else
              ["scoped_state: false", "scoped_state: true"]
            end
          )
        File.write(path, File.read(path).sub(before, after))
      when "added_environment_hook_setup_spec"
        File.write("spec/0_new_hook_spec.rb", <<~RUBY)
          RSpec.describe("New scoped hook") do
            before(:each) { ENV["FILE_PLAN_SCOPED_STATE"] = "changed" }
            it('passes independently') { expect(true).to eq(true) }
          end
        RUBY
      when "derived_metadata_setup_spec", "derived_description_setup_spec"
        path = "spec/1_writer_spec.rb"
        before, after =
          (
            if @name == "derived_metadata_setup_spec"
              ['file_plan_setup: "original"', 'file_plan_setup: "changed"']
            else
              ['"Original group"', '"Changed group"']
            end
          )
        File.write(path, File.read(path).sub(before, after))
      when "new_setup_spec"
        File.write(
          "spec/4_setup_spec.rb",
          "require_relative 'helper'\n#{test_setup_hook(value: "changed")}RSpec.describe('New setup spec') { it('passes') { expect(true).to eq(true) } }\n",
        )
      when "changed_setup_spec"
        File.open("spec/1_writer_spec.rb", "a") do |file|
          file.puts test_setup_hook(value: "changed")
        end
      when "removed_setup_spec"
        File.unlink("spec/1_writer_spec.rb")
      when "isolated_setup_spec", "isolated_configuration_setup_spec",
           "mapping_lag_isolated_setup_spec"
        path = "spec/1_writer_spec.rb"
        File.write(path, File.read(path).sub("be_a(Symbol)", "eq(:broken)"))
      when "configuration_alias_setup_spec"
        path = "spec/1_writer_spec.rb"
        File.write(path, File.read(path).sub('= "original"', '= "changed"'))
      when "captured_value_setup_spec", "provider_method_setup_spec", "included_helper_setup_spec",
           "environment_assignment_setup_spec", "conditional_setup_spec",
           "matcher_definition_setup_spec", "shared_context_setup_spec"
        path = "spec/1_writer_spec.rb"
        File.write(
          path,
          File.read(path).sub(
            test_setup_hook(value: "original"),
            test_setup_hook(value: "changed"),
          ),
        )
      when "added_matcher_setup_spec"
        File.write("spec/4_setup_spec.rb", <<~RUBY)
          #{test_setup_hook(value: "changed")}
          RSpec.describe('New matcher spec') { it('passes') { expect("changed").to match_shared_setup } }
        RUBY
      when "added_mocks_setup_spec"
        File.write("spec/4_setup_spec.rb", <<~RUBY)
          RSpec::Mocks.configuration.verify_partial_doubles = true
          RSpec.describe('New mocks spec') { it('passes') { expect(true).to eq(true) } }
        RUBY
      when "new_library_setup_spec"
        File.write("spec/4_setup_spec.rb", <<~RUBY)
          require_relative '../lib/extra_setup'
          RSpec.describe('New library spec') { it('passes') { expect(ENV["FILE_PLAN_SHARED_SETUP"]).to eq("changed") } }
        RUBY
      when "removed_library_setup_spec"
        File.unlink("spec/1_writer_spec.rb")
      when "renamed_library_setup_spec"
        File.rename("spec/1_writer_spec.rb", "spec/4_writer_spec.rb")
      when "mapping_lag_setup_spec", "mapping_lag_context_setup_spec"
        path = "lib/producer.rb"
        File.write(path, File.read(path).sub(":original", ":broken"))
      when "literal_setup_spec"
        File.write("spec/4_setup_spec.rb", <<~RUBY)
          RSpec.describe('Configuration string data') do
            it('exposes only the new assertion failure') { expect("RSpec.configure { |config| config.before(:suite) {} }").to eq("different data") }
          end
        RUBY
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
      if @name == "constant_hook_random_state"
        File.open("vendor/cache.rb", "a") do |file|
          file.puts
          file.puts <<~RUBY
            module SharedRandomStateHook
              def const_added(name)
                if self.name == "SharedRandomStateNamespace" && name == :Entry
                  Kernel.srand(SharedStateProducer.value)
                end
                super
              end
            end
            Module.prepend(SharedRandomStateHook)
            module SharedRandomStateNamespace
            end
          RUBY
        end
        action = "SharedRandomStateNamespace.const_set(:Entry, true)"
      elsif @name == "namespaced_matcher_random_state"
        File.open("vendor/cache.rb", "a") do |file|
          file.puts
          file.puts <<~RUBY
            class RSpec::Matchers::SharedRandomMatcher
              def matches?(actual)
                Kernel.srand(actual)
                true
              end
            end
            SharedRandomMatcher = RSpec::Matchers::SharedRandomMatcher.new
          RUBY
        end
        File.open("spec/helper.rb", "a") { |file| file.puts <<~RUBY }
            require "timeout"
            RSpec.configure do |config|
              config.around do |example|
                Timeout.timeout(30) { example.run }
              end
            end
          RUBY
        action = "expect(SharedStateProducer.value).to SharedRandomMatcher"
      elsif @name == "matcher_random_state"
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
               namespaced_matcher_random_state
               constant_hook_random_state
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
