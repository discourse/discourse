# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/create_upcoming_change_status_prs" do # rubocop:disable RSpec/DescribeClass
  let(:tmpdir) { Dir.mktmpdir("upcoming-change-status-prs") }
  let(:report_file) { File.join(tmpdir, "report.json") }
  let(:summary_file) { File.join(tmpdir, "summary.md") }
  let(:command_log) { File.join(tmpdir, "commands.log") }
  let(:fake_bin) { File.join(tmpdir, "bin") }
  let(:fake_rails) { File.join(fake_bin, "rails") }

  before do
    FileUtils.mkdir_p(fake_bin)
    write_fake_executable("git", <<~BASH)
      #!/usr/bin/env bash
      echo "git $*" >> "${COMMAND_LOG}"
    BASH
    write_fake_executable("gh", <<~BASH)
      #!/usr/bin/env bash
      echo "gh $*" >> "${COMMAND_LOG}"

      if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
        echo original-author
      elif [ "$1" = "pr" ] && [ "$2" = "list" ]; then
        echo "${EXISTING_PR_COUNT:-0}"
      fi
    BASH
    write_fake_executable("rails", <<~BASH)
      #!/usr/bin/env bash
      echo "rails $*" >> "${COMMAND_LOG}"
    BASH
    write_fake_executable("jq", <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      args = ARGV.dup
      args.delete("-r")
      args.delete("-c")
      filter = args.shift
      input = args.empty? ? STDIN.read : File.read(args.shift)
      data = JSON.parse(input)

      if filter == ".[] | select(.eligible)"
        data.select { |record| record["eligible"] }.each { |record| puts JSON.generate(record) }
      elsif filter.match?(/\A\.[a-z_]+( \/\/ empty)?\z/)
        field = filter.delete_prefix(".").delete_suffix(" // empty")
        print(data[field] || "")
      else
        warn "Unsupported jq filter: #{filter}"
        exit 1
      end
    RUBY
    File.write(report_file, JSON.generate(report_records))
  end

  after { FileUtils.remove_entry(tmpdir) }

  it "prints dry-run PR commands for eligible changes" do
    stdout, stderr, status = run_script("DRY_RUN" => "true")

    expect(status).to be_success, stderr.presence || stdout
    expect(File.read(summary_file)).to include(
      "SKIP_DB_AND_REDIS=1 RAILS_DB=nonexistent bin/rails runner script/upcoming_changes_status_report -- --stale-after-days 14 --apply alpha_change",
      "git add plugins/chat/config/settings.yml",
      "gh pr create --base main --head dev/upcoming-change-status-bump/alpha_change",
      "--label upcoming-change",
      "--assignee original-author",
    )
    expect(File.read(summary_file)).not_to include("stable_change")
  end

  it "creates a pull request for each eligible change" do
    stdout, stderr, status = run_script("DRY_RUN" => "false")

    expect(status).to be_success, stderr.presence || stdout
    expect(File.read(command_log)).to include(
      "git fetch origin main",
      "gh pr list --head dev/upcoming-change-status-bump/alpha_change --state open --json number --jq length",
      "git checkout -B dev/upcoming-change-status-bump/alpha_change origin/main",
      "rails runner script/upcoming_changes_status_report -- --stale-after-days 14 --apply alpha_change",
      "git add plugins/chat/config/settings.yml",
      "git commit -m FEATURE: Bump alpha_change upcoming change to beta",
      "git push -f origin dev/upcoming-change-status-bump/alpha_change",
      "gh pr create --base main --head dev/upcoming-change-status-bump/alpha_change --title FEATURE: Bump alpha_change upcoming change to beta --body-file /tmp/upcoming-change-alpha_change-body.md --label upcoming-change --assignee original-author",
    )
    expect(File.read("/tmp/upcoming-change-alpha_change-body.md")).to include(
      "<!-- upcoming-change-status-pr:alpha_change -->",
      "This automated PR moves `alpha_change` from `alpha` to `beta`",
    )
  end

  it "skips branches that already have open pull requests" do
    stdout, stderr, status = run_script("DRY_RUN" => "false", "EXISTING_PR_COUNT" => "1")

    expect(status).to be_success, stderr.presence || stdout
    expect(File.read(command_log)).to include(
      "gh pr list --head dev/upcoming-change-status-bump/alpha_change --state open --json number --jq length",
    )
    expect(File.read(command_log)).not_to include(
      "git checkout -B dev/upcoming-change-status-bump/alpha_change origin/main",
    )
  end

  def report_records
    [
      {
        name: "alpha_change",
        settings_path: "plugins/chat/config/settings.yml",
        current_status: "alpha",
        next_status: "beta",
        eligible: true,
        original_pr_number: "123",
        branch: "dev/upcoming-change-status-bump/alpha_change",
        title: "FEATURE: Bump alpha_change upcoming change to beta",
        pr_label: "upcoming-change",
        pr_body:
          "<!-- upcoming-change-status-pr:alpha_change -->\n\nThis automated PR moves `alpha_change` from `alpha` to `beta`.",
      },
      { name: "stable_change", current_status: "stable", next_status: nil, eligible: false },
    ]
  end

  def run_script(env)
    Open3.capture3(
      {
        "PATH" => "#{fake_bin}:#{ENV["PATH"]}",
        "COMMAND_LOG" => command_log,
        "REPORT_FILE" => report_file,
        "BASE_BRANCH" => "main",
        "STALE_AFTER_DAYS" => "14",
        "GITHUB_REPOSITORY" => "discourse/discourse",
        "GITHUB_STEP_SUMMARY" => summary_file,
        "RAILS_COMMAND" => fake_rails,
        **env,
      },
      "script/create_upcoming_change_status_prs",
      chdir: Rails.root.to_s,
    )
  end

  def write_fake_executable(name, content)
    path = File.join(fake_bin, name)
    File.write(path, content)
    FileUtils.chmod("+x", path)
  end
end
