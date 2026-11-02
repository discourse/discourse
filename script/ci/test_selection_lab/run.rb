# frozen_string_literal: true
require "fileutils"
require "json"
require "open3"
require "rbconfig"

source = File.expand_path("../../..", __dir__)
raise ArgumentError, "Expected a new disposable directory" unless ARGV.length == 1
workspace = File.expand_path(ARGV.first)
if workspace.start_with?("#{source}/") || File.exist?(workspace)
  raise ArgumentError, "Workspace must be outside the checkout and must not exist"
end
unless system("git", "diff", "--quiet", "HEAD", chdir: source)
  raise "Commit the source before verification"
end
FileUtils.mkdir_p(workspace)
statuses = Open3.pipeline(["git", "-C", source, "archive", "HEAD"], ["tar", "-x", "-C", workspace])
raise "Cannot create disposable snapshot" unless statuses.all?(&:success?)
%w[
  .bundle
  config/database.yml
  config/redis.yml
  public/assets
  node_modules
  vendor/bundle
  vendor/runtime_node_modules
  tmp/playwright
].each do |path|
  target = File.join(workspace, path)
  original = File.join(source, path)
  next unless File.exist?(original) && !File.exist?(target)
  FileUtils.mkdir_p(File.dirname(target))
  File.symlink(original, target)
end
FileUtils.mkdir_p(File.join(workspace, "log"))
FileUtils.mkdir_p(File.join(workspace, "tmp"))
Dir.chdir(workspace) do
  ENV["BUNDLE_GEMFILE"] = File.join(workspace, "Gemfile")
  [
    %w[init -q],
    %w[config user.email file-plan-lab@example.invalid],
    ["config", "user.name", "File plan lab"],
    %w[config core.hooksPath /dev/null],
  ].each { |arguments| system("git", *arguments, exception: true) }
  tracked_files, status =
    Open3.capture2("git", "-C", source, "ls-tree", "-rz", "--name-only", "HEAD")
  raise "Cannot read source inventory" unless status.success?
  _, error, status =
    Open3.capture3(
      "git",
      "add",
      "--force",
      "--pathspec-from-file=-",
      "--pathspec-file-nul",
      stdin_data: tracked_files,
    )
  raise error unless status.success?
  system(
    "git",
    "-c",
    "commit.gpgsign=false",
    "commit",
    "-qm",
    "File plan baseline",
    exception: true,
  )
  source_tree, source_status = Open3.capture2("git", "-C", source, "rev-parse", "HEAD^{tree}")
  snapshot_tree, snapshot_status = Open3.capture2("git", "rev-parse", "HEAD^{tree}")
  unless source_status.success? && snapshot_status.success? && snapshot_tree == source_tree
    raise "Snapshot does not match source"
  end
  begin
    load File.join(source, "script/ci/test_selection_lab/collect.rb")
    load File.join(source, "script/ci/test_selection_lab/scenarios.rb")
    load File.join(source, "script/ci/test_selection_lab/shared_state.rb")
    evidence = "tmp/proof/file-selection-lab"
    results =
      Dir["#{evidence}/scenarios/*/result.json"].sort.map { |path| JSON.parse(File.read(path)) }
    File.write("#{evidence}/results.json", JSON.pretty_generate(results))
  ensure
    evidence = "tmp/proof/file-selection-lab"
    if File.directory?(evidence)
      system(
        RbConfig.ruby,
        File.join(source, "script/ci/test_selection_lab/report.rb"),
        evidence,
        "#{evidence}/report.html",
        exception: true,
      )
    end
  end
end
puts "Retained evidence: #{workspace}/tmp/proof/file-selection-lab"
