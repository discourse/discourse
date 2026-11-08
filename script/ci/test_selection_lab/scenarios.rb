# frozen_string_literal: true
require "json"
require "fileutils"
require File.expand_path("script/ci/test_plan", Dir.pwd)
require File.expand_path("script/ci/test_inventory", Dir.pwd)
require File.expand_path("script/ci/test_execution", Dir.pwd)
base = File.read("tmp/proof/file-selection-lab/baseline-revision").strip
baseline = JSON.parse(File.read("tmp/proof/file-selection-lab/catalog.json"))
inventory = baseline.fetch("jobs").fetch("core-backend").fetch("inventory")
added = "spec/lib/file_plan_new_spec.rb"
cases = [
  [
    "accessor_method_body_shared_uncertainty",
    inventory,
    "The banner value flows through exists? into a shared initialization dependency. The published collector also broadens this exact method change. Unknown effects protect the full owning inventory, although only the archetype example fails. This case does not establish that every extra passing spec is necessary.",
    -> do
      path = "lib/archetype.rb"
      original = File.read(path)
      before = '    "banner"'
      after = '    "file_plan_missing"'
      raise "Archetype banner definition changed" unless original.include?(before)
      File.write(path, original.sub(before, after))
    end,
  ],
  [
    "new_spec",
    (inventory + [added]).sort,
    "The added group registers definitions that another file can inspect. Unknown reader ownership protects the complete environment. Existing passing files are a conservative efficiency cost. Rails and Bundler must use this disposable checkout.",
    -> do
      File.write(
        added,
        'RSpec.describe("New file plan test") { it("normalizes a username") { expect(Bundler.default_gemfile.realpath.to_s).to eq(File.realpath("Gemfile")); expect(Rails.root.to_s).to eq(Dir.pwd); expect(User.normalize_username("ALICE")).to eq("alice") } }',
      )
    end,
  ],
  [
    "flaky_retry",
    (inventory + [added]).sort,
    "The new group protects the complete owning environment. Its example fails once and passes through the existing Turbo retry. The assignment and seed must remain valid across both attempts.",
    -> do
      File.write(
        added,
        'RSpec.describe("Retry file plan test") { it("passes on retry") { path = "tmp/proof/retry-attempt"; first_attempt = !File.exist?(path); File.write(path, "attempt"); expect(first_attempt).to eq(false) } }',
      )
    end,
  ],
  [
    "changed_spec",
    inventory,
    "The added example registers a definition visible through the RSpec registry. Unknown reader ownership protects this environment, including existing passing files.",
    -> do
      File.open("spec/lib/pbkdf2_spec.rb", "a") do |file|
        file.puts '\nRSpec.describe("Added assertion") { it("passes") { expect(1 + 1).to eq(2) } }'.gsub(
                    '\\n',
                    "\n",
                  )
      end
    end,
  ],
  [
    "documentation",
    [],
    "The root Markdown change cannot alter test execution.",
    -> { File.open("README.md", "a") { |file| file.puts "\nFile selection proof." } },
  ],
  [
    "mapped_helper",
    inventory,
    "The injected early return bypasses existing helper calls. Recorded dependencies cannot establish the effects of the new control flow, so every file in this environment remains eligible.",
    -> do
      path = "lib/url_helper.rb"
      File.write(
        path,
        File.read(path).sub(
          "  def self.normalized_encode(uri)\n",
          "  def self.normalized_encode(uri)\n    return \"https://broken.invalid\"\n",
        ),
      )
    end,
  ],
  [
    "new_application_file",
    inventory,
    "No previous mapping can establish the effects of this new application source. All files in this environment are justified by uncertainty.",
    -> { File.write("lib/file_plan_unknown.rb", "module FilePlanUnknown; end") },
  ],
  [
    "shared_configuration",
    inventory,
    "Application setup is shared by every file in this environment.",
    -> do
      File.open("config/application.rb", "a") do |file|
        file.puts "\nENV[\"FILE_PLAN_CONFIGURATION_PROBE\"] = \"1\""
      end
    end,
  ],
  [
    "deleted_spec",
    inventory - ["spec/lib/freedom_patches/translate_accelerator_spec.rb"],
    "Deleting a registered group can affect registry readers. The removed file is omitted and unknown reader ownership protects every remaining file in this environment.",
    -> { File.unlink("spec/lib/freedom_patches/translate_accelerator_spec.rb") },
  ],
  [
    "renamed_spec",
    (
      inventory - ["spec/lib/freedom_patches/translate_accelerator_spec.rb"] +
        ["spec/lib/freedom_patches/file_plan_renamed_spec.rb"]
    ).sort,
    "Moving a registered definition can affect load order and registry readers. The destination and every remaining file stay eligible. The removed source never runs.",
    -> do
      File.rename(
        "spec/lib/freedom_patches/translate_accelerator_spec.rb",
        "spec/lib/freedom_patches/file_plan_renamed_spec.rb",
      )
    end,
  ],
  [
    "deleted_autoload_spec",
    inventory - ["spec/models/badge_grouping_spec.rb"],
    "The deleted group resolves a class constant. Removing that lookup can remove an autoload side effect, so all remaining files stay eligible.",
    -> { File.unlink("spec/models/badge_grouping_spec.rb") },
  ],
  [
    "renamed_autoload_spec",
    (
      inventory - ["spec/models/badge_grouping_spec.rb"] + ["spec/models/file_plan_renamed_spec.rb"]
    ).sort,
    "Moving a class declaration can move its autoload in file load order. The destination and every remaining file stay eligible.",
    -> do
      File.rename("spec/models/badge_grouping_spec.rb", "spec/models/file_plan_renamed_spec.rb")
    end,
  ],
  [
    "deleted_library_spec",
    inventory - ["spec/lib/pbkdf2_spec.rb"],
    "This spec also loads a library outside its example group. Removing that load can affect shared initialization, so the remaining environment stays eligible. The removed file never runs.",
    -> { File.unlink("spec/lib/pbkdf2_spec.rb") },
  ],
  [
    "renamed_library_spec",
    (inventory - ["spec/lib/pbkdf2_spec.rb"] + ["spec/lib/file_plan_renamed_spec.rb"]).sort,
    "This renamed spec loads a library outside its example group. Moving the load can change initialization order, so the whole environment remains eligible. The destination runs and the removed source is omitted.",
    -> { File.rename("spec/lib/pbkdf2_spec.rb", "spec/lib/file_plan_renamed_spec.rb") },
  ],
  [
    "renamed_spec_with_helper",
    (inventory - ["spec/lib/pbkdf2_spec.rb"] + ["spec/lib/file_plan_renamed_spec.rb"]).sort,
    "The renamed destination always runs. The helper change introduces an early return that bypasses existing calls, so every remaining file in this environment must run.",
    -> do
      File.rename("spec/lib/pbkdf2_spec.rb", "spec/lib/file_plan_renamed_spec.rb")
      path = "lib/url_helper.rb"
      File.write(
        path,
        File.read(path).sub(
          "  def self.normalized_encode(uri)\n",
          "  def self.normalized_encode(uri)\n    return \"https://broken.invalid\"\n",
        ),
      )
    end,
  ],
]
results = []
cases.each do |name, expected, why, change|
  next if results.any? { |result| result.fetch("case") == name }
  abort "reset failed" unless system("git", "reset", "--hard", base, out: File::NULL)
  change.call
  unless system("git", "add", ".") &&
           system("git", "-c", "commit.gpgsign=false", "commit", "-qm", "Scenario #{name}")
    abort "commit failed"
  end
  revision = `git rev-parse HEAD`.strip
  ENV["GITHUB_SHA"] = revision
  ENV["COLLECT_TEST_MAPPING"] = "0"
  ENV["COLLECT_RSPEC_MAPPING"] = "0"
  ENV["PARALLEL_TEST_PROCESSORS"] = "2"
  ENV["DISCOURSE_TURBO_RSPEC_RETRY_AND_LOG_FLAKY_TESTS"] = name == "flaky_retry" ? "1" : "0"
  FileUtils.rm_f("tmp/proof/retry-attempt") if name == "flaky_retry"
  directory = "tmp/proof/file-selection-lab/scenarios/#{name}"
  FileUtils.mkdir_p(directory)
  File.write(
    "#{directory}/expected.json",
    JSON.pretty_generate("files" => expected.sort, "why" => why),
  )
  File.write("#{directory}/changes.diff", `git diff #{base}...#{revision}`)
  catalog = Marshal.load(Marshal.dump(baseline))
  catalog["revision"] = revision
  added_tests =
    `git diff --no-renames --diff-filter=A --name-only -z #{base}...#{revision}`.split("\0")
  current_core = TestInventory.jobs(bundled: []).fetch("core-backend").fetch("inventory")
  catalog["jobs"]["core-backend"]["inventory"] = (
    (inventory & current_core) + (added_tests & current_core)
  ).uniq.sort
  File.write("#{directory}/catalog.json", JSON.pretty_generate(catalog))
  TestPlan.prepare(
    catalog_path: "#{directory}/catalog.json",
    mapping_directory: "tmp/proof/file-selection-lab/mappings",
    base: base,
    revision: revision,
    output: "#{directory}/plan.json",
    mode: "select",
    main: false,
  )
  plan = JSON.parse(File.read("#{directory}/plan.json"))
  unless plan.fetch("files") == expected.sort
    abort "#{name}: selected #{plan.fetch("files")}, expected #{expected.sort}"
  end
  selected_ok =
    system(
      "ruby",
      "script/ci/test_execution.rb",
      "#{directory}/plan.json",
      "#{directory}/catalog.json",
      "core-backend",
      "#{directory}/selected.json",
      out: "#{directory}/selected.log",
      err: %i[child out],
    )
  selected = JSON.parse(File.read("#{directory}/selected.json"))
  abort "#{name}: selected execution mismatch" unless selected.fetch("exact")
  TestPlan.prepare(
    catalog_path: "#{directory}/catalog.json",
    mapping_directory: "tmp/proof/file-selection-lab/mappings",
    base: base,
    revision: revision,
    output: "#{directory}/audit.json",
    mode: "audit",
    main: false,
  )
  unless JSON.parse(File.read("#{directory}/audit.json.reference.json")).fetch("files") ==
           catalog.fetch("jobs").fetch("core-backend").fetch("inventory")
    abort "#{name}: audit skipped tests"
  end
  FileUtils.rm_f("tmp/proof/retry-attempt") if name == "flaky_retry"
  system(
    "ruby",
    "script/ci/test_execution.rb",
    "#{directory}/audit.json.reference.json",
    "#{directory}/catalog.json",
    "core-backend",
    "#{directory}/full.json",
    out: "#{directory}/full.log",
    err: %i[child out],
  )
  full = JSON.parse(File.read("#{directory}/full.json"))
  abort "#{name}: full execution mismatch" unless full.fetch("exact")
  unless [selected, full].all? { |report|
           !report.fetch("non_example_failure") && !report.fetch("unreported_failure")
         }
    abort "#{name}: incomplete execution comparison"
  end
  unless (full.fetch("failures") - selected.fetch("failures")).empty?
    abort "#{name}: missed failure"
  end
  unless (
           if %w[
                mapped_helper
                renamed_spec_with_helper
                accessor_method_body_shared_uncertainty
              ].include?(name)
             !selected_ok && selected.fetch("failures").any? && full.fetch("failures").any?
           else
             selected_ok && full.fetch("success")
           end
         )
    abort "#{name}: unexpected run result"
  end
  result = {
    "case" => name,
    "base" => base,
    "revision" => revision,
    "changes" => JSON.parse(File.read("#{directory}/plan.json.input.json")).fetch("changes"),
    "expected" => expected.sort,
    "selected" => plan.fetch("files"),
    "reasons" => plan.fetch("reasons"),
    "executed" => selected.fetch("loaded"),
    "why" => why,
    "selected_failures" => selected.fetch("failures"),
    "full_failures" => full.fetch("failures"),
    "correct" => true,
  }
  File.write("#{directory}/result.json", JSON.pretty_generate(result))
  results << result
  File.write("tmp/proof/file-selection-lab/results.json", JSON.pretty_generate(results))
  puts JSON.generate(result)
end
