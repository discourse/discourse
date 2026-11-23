# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"

RSpec.describe "Core system test selection in shadow" do
  let(:selector) { File.expand_path("../../script/ci/core_system_test_selection.rb", __dir__) }
  let(:sidebar) { "spec/system/editing_sidebar_tags_navigation_spec.rb" }
  let(:about) { "spec/system/about_page_spec.rb" }
  let(:unrelated) { "spec/system/some_other_spec.rb" }
  let(:controller) { "app/controllers/tags_controller.rb" }
  let(:helper) { "lib/example_helper.rb" }

  around do |example|
    Dir.mktmpdir do |directory|
      @repo = directory
      git("init", "--quiet")
      git("config", "user.name", "Discourse CI")
      git("config", "user.email", "ci@ci.invalid")
      [sidebar, about, unrelated, controller, helper].each { |path| write(path, "base\n") }
      @map_sha = commit("collected")
      example.run
    end
  end

  def git(*arguments)
    stdout, stderr, status = Open3.capture3("git", *arguments, chdir: @repo)
    raise stderr unless status.success?
    stdout.strip
  end

  def write(path, contents)
    absolute = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, contents)
  end

  def commit(message)
    git("add", "--all")
    git("commit", "--quiet", "-m", message)
    git("rev-parse", "HEAD")
  end

  def selection(dependencies:, base:)
    payload = {
      version: 1,
      revision: @map_sha,
      spec_files: [sidebar, about, unrelated],
      boot_sources: [],
      tests_by_source: dependencies,
    }
    map_path = File.join(@repo, ".git/mapping.json")
    report_path = File.join(@repo, ".git/shadow.json")
    File.write(map_path, JSON.generate(payload))
    _, stderr, status =
      Open3.capture3(
        { "CORE_SYSTEM_PR_BASE" => base, "CORE_SYSTEM_MAP_SHA" => @map_sha },
        RbConfig.ruby,
        selector,
        "plan",
        map_path,
        report_path,
        chdir: @repo,
      )
    raise stderr unless status.success?
    JSON.parse(File.read(report_path))
  end

  it "combines changes since collection with changes in the tested pull request" do
    write(controller, "main changed the controller\n")
    new_spec = "spec/system/new_tag_filters_spec.rb"
    write(new_spec, "new test\n")
    base = commit("main changed the code and added a test")
    write(helper, "the pull request changed the helper\n")
    commit("pull request")

    report = selection(dependencies: { controller => [sidebar], helper => [about] }, base:)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, new_spec)
    expect(report.fetch("main_drift")).to contain_exactly(controller, new_spec)
    expect(report.fetch("pull_request_changes")).to eq([helper])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "keeps the drift selection when a pull request reverts a main change" do
    write(controller, "main changed the controller\n")
    base = commit("main changed the controller")
    write(controller, "base\n")
    commit("pull request reverted the controller")

    report = selection(dependencies: { controller => [sidebar] }, base:)

    expect(report.fetch("selected_files")).to eq([sidebar])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "falls back to the full suite when a change since collection has no map entry" do
    write(controller, "main changed the controller\n")
    base = commit("main changed the controller")
    write(helper, "the pull request changed the helper\n")
    commit("pull request")

    report = selection(dependencies: { helper => [about] }, base:)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("unmapped_input")
  end
end
