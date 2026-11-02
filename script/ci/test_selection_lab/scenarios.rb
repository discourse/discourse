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
    "new_spec",
    [added],
    "Only the added spec contains new test behavior. Rails and Bundler must use this disposable checkout.",
    -> do
      File.write(
        added,
        'RSpec.describe("New file plan test") { it("normalizes a username") { expect(Bundler.default_gemfile.realpath.to_s).to eq(File.realpath("Gemfile")); expect(Rails.root.to_s).to eq(Dir.pwd); expect(User.normalize_username("ALICE")).to eq("alice") } }',
      )
    end,
  ],
  [
    "flaky_retry",
    [added],
    "The new spec fails once and passes through the existing Turbo retry. The assignment and seed must remain valid across both attempts.",
    -> do
      File.write(
        added,
        'RSpec.describe("Retry file plan test") { it("passes on retry") { path = "tmp/proof/retry-attempt"; first_attempt = !File.exist?(path); File.write(path, "attempt"); expect(first_attempt).to eq(false) } }',
      )
    end,
  ],
  [
    "changed_spec",
    ["spec/lib/pbkdf2_spec.rb"],
    "Only this spec changed. Existing application behavior is unchanged.",
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
    [],
    "The deleted spec cannot execute and no application file changed.",
    -> { File.unlink("spec/lib/pbkdf2_spec.rb") },
  ],
  [
    "renamed_spec",
    ["spec/lib/file_plan_renamed_spec.rb"],
    "The destination is a new test file. The removed source file cannot execute.",
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
  catalog["jobs"]["core-backend"]["inventory"] = (
    inventory.select { |file| File.file?(file) } +
      (
        %w[new_spec flaky_retry].include?(name) ?
          [added] :
          if %w[renamed_spec renamed_spec_with_helper].include?(name)
            ["spec/lib/file_plan_renamed_spec.rb"]
          else
            []
          end
      )
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
  unless (full.fetch("failures") - selected.fetch("failures")).empty?
    abort "#{name}: missed failure"
  end
  unless (
           if %w[mapped_helper renamed_spec_with_helper].include?(name)
             !selected_ok && selected.fetch("failures").any?
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
