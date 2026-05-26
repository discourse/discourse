# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/create_upcoming_change_status_prs" do # rubocop:disable RSpec/DescribeClass
  let(:tmpdir) { Dir.mktmpdir("upcoming-change-status-prs") }
  let(:report_file) { File.join(tmpdir, "report.json") }
  let(:summary_file) { File.join(tmpdir, "summary.md") }
  let(:fake_bin) { File.join(tmpdir, "bin") }

  before do
    FileUtils.mkdir_p(fake_bin)
    write_fake_executable("git", "#!/usr/bin/env bash\nexit 0\n")
    write_fake_executable("gh", <<~BASH)
        #!/usr/bin/env bash
        if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
          echo original-author
        fi
      BASH
    File.write(
      report_file,
      JSON.generate(
        [
          {
            name: "alpha_change",
            current_status: "alpha",
            next_status: "beta",
            eligible: true,
            original_pr_number: "123",
            original_author_name: "Alice Example",
            original_author_email: "alice@example.com",
            last_status_change_commit: "abc123",
            last_status_change_date: "2026-04-01T00:00:00Z",
          },
          { name: "stable_change", current_status: "stable", next_status: nil, eligible: false },
        ],
      ),
    )
  end

  after { FileUtils.remove_entry(tmpdir) }

  it "prints dry-run PR commands for eligible changes" do
    stdout, stderr, status =
      Open3.capture3(
        {
          "PATH" => "#{fake_bin}:#{ENV["PATH"]}",
          "REPORT_FILE" => report_file,
          "BASE_BRANCH" => "main",
          "DRY_RUN" => "true",
          "STALE_AFTER_DAYS" => "14",
          "GITHUB_REPOSITORY" => "discourse/discourse",
          "GITHUB_STEP_SUMMARY" => summary_file,
        },
        "script/create_upcoming_change_status_prs",
        chdir: Rails.root.to_s,
      )

    expect(status).to be_success, stderr.presence || stdout
    expect(File.read(summary_file)).to include(
      "SKIP_DB_AND_REDIS=1 RAILS_DB=nonexistent bin/rails runner script/upcoming_changes_status_report -- --stale-after-days 14 --apply alpha_change",
      "gh pr create --base main --head dev/upcoming-change-status-bump/alpha_change",
      "--assignee original-author",
    )
    expect(File.read(summary_file)).not_to include("stable_change")
  end

  def write_fake_executable(name, content)
    path = File.join(fake_bin, name)
    File.write(path, content)
    FileUtils.chmod("+x", path)
  end
end
