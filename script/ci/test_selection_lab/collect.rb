# frozen_string_literal: true
require File.expand_path("script/ci/test_inventory", Dir.pwd)
require File.expand_path("script/ci/test_selection", Dir.pwd)
require File.expand_path("script/ci/test_mapping", Dir.pwd)
revision = `git rev-parse HEAD`.strip
ENV["GITHUB_SHA"] = revision
ENV["PARALLEL_TEST_PROCESSORS"] = "2"
ENV["COLLECT_TEST_MAPPING"] = "1"
ENV["COLLECT_RSPEC_MAPPING"] = "1"
ENV["TEST_MAPPING_DIRECTORY"] = File.expand_path("tmp/proof/file-selection-lab/raw")
files = %w[
  spec/lib/url_helper_spec.rb
  spec/lib/pbkdf2_spec.rb
  spec/lib/archetype_spec.rb
  spec/lib/plaintext_mentions_spec.rb
  spec/models/badge_grouping_spec.rb
  spec/lib/freedom_patches/translate_accelerator_spec.rb
].sort
catalog = TestInventory.catalog(revision: revision)
catalog.delete("repository_catalog")
catalog["jobs"].select! { |name, _| name == "core-backend" }
catalog["jobs"]["core-backend"]["inventory"] = files
FileUtils.mkdir_p("tmp/proof/file-selection-lab/mappings")
File.write("tmp/proof/file-selection-lab/catalog.json", JSON.pretty_generate(catalog))
input =
  catalog.merge(
    "mode" => "full",
    "main" => true,
    "changes" => [],
    "test_changes" => [],
    "deleted_tests" => [],
    "jobs" =>
      catalog["jobs"].transform_values do |job|
        job.merge("mapping_changes" => [], "verified_sources" => [])
      end,
  )
File.write(
  "tmp/proof/file-selection-lab/baseline-plan.json",
  JSON.pretty_generate(TestSelection::Planner.new(input).plan),
)
unless system(
         "ruby",
         "script/ci/test_execution.rb",
         "tmp/proof/file-selection-lab/baseline-plan.json",
         "tmp/proof/file-selection-lab/catalog.json",
         "core-backend",
         "tmp/proof/file-selection-lab/baseline-execution.json",
       )
  abort "baseline execution failed"
end
TestMapping.merge(
  catalog: catalog,
  job_name: "core-backend",
  directory: ENV.fetch("TEST_MAPPING_DIRECTORY"),
  execution_directory: "tmp/proof/file-selection-lab/baseline-execution.json.workers",
  output: "tmp/proof/file-selection-lab/mappings/core-backend.json",
)
File.write("tmp/proof/file-selection-lab/baseline-revision", revision)
mapping = JSON.parse(File.read("tmp/proof/file-selection-lab/mappings/core-backend.json"))
puts JSON.pretty_generate(
       "revision" => revision,
       "files" => files,
       "mapping_tests" => mapping.fetch("tests").keys,
       "source_count" => mapping.fetch("sources").length,
       "initialization_count" => mapping.fetch("initialization_sources").length,
       "shared_count" => mapping.fetch("shared_files").length,
     )
