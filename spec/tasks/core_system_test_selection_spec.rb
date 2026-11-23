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
  let(:controller_source) { <<~RUBY }
      class TagsController
        before_action :require_login
        def list
          :before
        end
        def warm
          :booted
        end
      end
    RUBY
  let(:helper) { "lib/example_helper.rb" }
  let(:helper_source) { <<~RUBY }
      module ExampleHelper
        FORMAT = :original
        def format
          :before
        end
      end
    RUBY

  around do |example|
    Dir.mktmpdir do |directory|
      @repo = directory
      git("init", "--quiet")
      git("config", "user.name", "Discourse CI")
      git("config", "user.email", "ci@ci.invalid")
      [sidebar, about, unrelated].each { |path| write(path, "base\n") }
      write(helper, helper_source)
      write(controller, controller_source)
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

  def selection(
    dependencies: nil,
    unmapped_browser_specs: [],
    setup_lines: {},
    github_sha: nil,
    pull_request_head: nil
  )
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "HEAD^")
    tree = git("rev-parse", "HEAD^{tree}")
    merge = git("commit-tree", tree, "-p", base, "-p", head, "-m", "Tested merge")
    git("update-ref", "HEAD", merge, head)
    payload = {
      version: 2,
      revision: @map_sha,
      spec_files: [sidebar, about, unrelated],
      boot_sources: setup_lines.keys,
      setup_lines:,
      tests_by_source: dependencies,
      unmapped_browser_specs:,
    }
    map_path = File.join(@repo, ".git/mapping.json")
    report_path = File.join(@repo, ".git/shadow.json")
    File.write(map_path, JSON.generate(payload)) if dependencies
    _, stderr, status =
      Open3.capture3(
        {
          "GITHUB_SHA" => github_sha || merge,
          "CORE_SYSTEM_PR_BASE" => @map_sha,
          "CORE_SYSTEM_PR_HEAD" => pull_request_head || head,
          "CORE_SYSTEM_MAP_SHA" => @map_sha,
        },
        RbConfig.ruby,
        selector,
        "plan",
        map_path,
        report_path,
        chdir: @repo,
      )
    raise stderr unless status.success?
    JSON.parse(File.read(report_path))
  ensure
    git("update-ref", "HEAD", head, merge) if merge
  end

  it "proposes zero Core system files for backend library specs when the event base is stale" do
    write(helper, helper_source.sub(":before", ":main"))
    commit("main changes application code")
    backend_spec = "spec/lib/example_helper_spec.rb"
    write(backend_spec, "new backend example\n")
    commit("pull request adds a backend example")

    report = selection

    expect(report).to include(
      "selected_files" => [],
      "full_suite_fallback" => nil,
      "pull_request_changes" => [backend_spec],
    )
  end

  it "uses the full suite without a map when a pull request changes backend specs and application code" do
    write("spec/lib/example_helper_spec.rb", "new backend example\n")
    write(helper, helper_source.sub(":before", ":after"))
    commit("pull request changes the helper and its backend spec")

    report = selection

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("no_compatible_map")
  end

  it "uses the full suite when the merge head differs from the event pull request head" do
    write("spec/lib/example_helper_spec.rb", "new backend example\n")
    commit("pull request adds a backend example")

    report = selection(pull_request_head: @map_sha)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("selection_error")
  end

  it "uses the full suite when the checkout differs from the event merge commit" do
    write("spec/lib/example_helper_spec.rb", "new backend example\n")
    commit("pull request adds a backend example")

    report = selection(github_sha: @map_sha)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("selection_error")
  end

  it "combines changes since collection with changes in the tested pull request" do
    write(controller, controller_source.sub(":before", ":main"))
    new_spec = "spec/system/new_tag_filters_spec.rb"
    write(new_spec, "new test\n")
    commit("main changed the code and added a test")
    write(helper, helper_source.sub(":before", ":after"))
    commit("pull request")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
          helper => [about],
        },
        setup_lines: {
          controller => [1, 2, 3],
          helper => [1, 2, 3],
        },
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, new_spec)
    expect(report.fetch("main_drift")).to contain_exactly(controller, new_spec)
    expect(report.fetch("pull_request_changes")).to eq([helper])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "keeps the drift selection when a pull request reverts a main change" do
    write(controller, controller_source.sub(":before", ":main"))
    commit("main changed the controller")
    write(controller, controller_source)
    commit("pull request reverted the controller")

    report =
      selection(dependencies: { controller => [sidebar] }, setup_lines: { controller => [1, 2, 3] })

    expect(report.fetch("selected_files")).to eq([sidebar])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "falls back to the full suite when a change since collection has no map entry" do
    write(controller, controller_source.sub(":before", ":main"))
    commit("main changed the controller")
    write(helper, helper_source.sub(":before", ":after"))
    commit("pull request")

    report = selection(dependencies: { helper => [about] }, setup_lines: { helper => [1, 2, 3] })

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("unmapped_input")
  end

  it "includes specs with incompletely mapped browser assets for application changes" do
    write(controller, controller_source.sub(":before", ":after"))
    commit("pull request")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        setup_lines: {
          controller => [1, 2, 3],
        },
        unmapped_browser_specs: [about],
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about)
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "uses runtime consumers for method edits within an eager loaded file" do
    write(controller, controller_source.sub(":before", ":during_main\n    :main"))
    commit("main method change")
    write(controller, controller_source.sub(":before", ":after"))
    commit("pull request method change")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        setup_lines: {
          controller => [1, 2, 3, 6, 7],
        },
      )

    expect(report.fetch("selected_files")).to eq([sidebar])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "uses the full suite when a method that ran at boot changes" do
    write(controller, controller_source.sub(":booted", ":different"))
    commit("pull request changes boot behavior")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        setup_lines: {
          controller => [1, 2, 3, 6, 7],
        },
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end

  it "uses the full suite when a pull request reverts a class declaration change on main" do
    write(controller, controller_source.sub("require_login", "ensure_tags_enabled"))
    commit("main changes callback registration")
    write(controller, controller_source)
    commit("pull request reverts callback registration")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        setup_lines: {
          controller => [1, 2, 3, 6, 7],
        },
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end

  it "uses the full suite when a declaration changes in a lazily loaded helper" do
    write(helper, helper_source.sub(":original", ":updated"))
    commit("pull request changes a lazy declaration")

    report = selection(dependencies: { helper => [about] })

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end

  it "uses the full suite when a method changes without coverage from every worker's boot" do
    write(helper, helper_source.sub(":before", ":updated"))
    commit("pull request changes a helper body")

    report = selection(dependencies: { helper => [about] })

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end
end
