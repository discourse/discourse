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

  def selection(dependencies:, base:, unmapped_browser_specs: [], boot_lines: {})
    payload = {
      version: 2,
      revision: @map_sha,
      spec_files: [sidebar, about, unrelated],
      boot_sources: boot_lines.keys,
      boot_lines:,
      tests_by_source: dependencies,
      unmapped_browser_specs:,
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
    write(controller, controller_source.sub(":before", ":main"))
    new_spec = "spec/system/new_tag_filters_spec.rb"
    write(new_spec, "new test\n")
    base = commit("main changed the code and added a test")
    write(helper, helper_source.sub(":before", ":after"))
    commit("pull request")

    report = selection(dependencies: { controller => [sidebar], helper => [about] }, base:)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, new_spec)
    expect(report.fetch("main_drift")).to contain_exactly(controller, new_spec)
    expect(report.fetch("pull_request_changes")).to eq([helper])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "keeps the drift selection when a pull request reverts a main change" do
    write(controller, controller_source.sub(":before", ":main"))
    base = commit("main changed the controller")
    write(controller, controller_source)
    commit("pull request reverted the controller")

    report = selection(dependencies: { controller => [sidebar] }, base:)

    expect(report.fetch("selected_files")).to eq([sidebar])
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "falls back to the full suite when a change since collection has no map entry" do
    write(controller, controller_source.sub(":before", ":main"))
    base = commit("main changed the controller")
    write(helper, helper_source.sub(":before", ":after"))
    commit("pull request")

    report = selection(dependencies: { helper => [about] }, base:)

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
        base: @map_sha,
        unmapped_browser_specs: [about],
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about)
    expect(report.fetch("full_suite_fallback")).to be_nil
  end

  it "uses runtime consumers for method edits within an eager loaded file" do
    write(controller, controller_source.sub(":before", ":during_main\n    :main"))
    base = commit("main method change")
    write(controller, controller_source.sub(":before", ":after"))
    commit("pull request method change")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        base:,
        boot_lines: {
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
        base: @map_sha,
        boot_lines: {
          controller => [1, 2, 3, 6, 7],
        },
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end

  it "uses the full suite when a pull request reverts a class declaration change on main" do
    write(controller, controller_source.sub("require_login", "ensure_tags_enabled"))
    base = commit("main changes callback registration")
    write(controller, controller_source)
    commit("pull request reverts callback registration")

    report =
      selection(
        dependencies: {
          controller => [sidebar],
        },
        base:,
        boot_lines: {
          controller => [1, 2, 3, 6, 7],
        },
      )

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end

  it "uses the full suite when a declaration changes in a lazily loaded helper" do
    write(helper, helper_source.sub(":original", ":updated"))
    commit("pull request changes a lazy declaration")

    report = selection(dependencies: { helper => [about] }, base: @map_sha)

    expect(report.fetch("selected_files")).to contain_exactly(sidebar, about, unrelated)
    expect(report.fetch("full_suite_fallback")).to eq("shared_input")
  end
end
