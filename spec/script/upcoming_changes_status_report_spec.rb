# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe UpcomingChanges::StatusReport do
  subject(:report) do
    described_class.new(repo_path:, stale_after_days: 14, now: Time.iso8601("2026-05-26T00:00:00Z"))
  end

  let(:repo_path) { Dir.mktmpdir("upcoming-changes-status-report") }
  let(:commit_shas) { {} }

  before do
    git("init")
    git("config", "user.name", "Discourse CI")
    git("config", "user.email", "ci@ci.invalid")

    write_settings(
      "experimental_change" => "experimental",
      "alpha_change" => "alpha",
      "beta_change" => "beta",
      "recent_change" => "alpha",
      "stable_change" => "stable",
      "conceptual_change" => "conceptual",
      "permanent_change" => "permanent",
      "never_change" => "never",
    )
    write_plugin_settings("plugin_alpha_change" => "alpha")
    commit_shas[:original] = commit(
      "FEATURE: Add upcoming changes (#123)",
      date: "2026-04-01T12:00:00Z",
      author_name: "Alice Example",
      author_email: "alice@example.com",
    )

    write_settings(
      "experimental_change" => "experimental",
      "alpha_change" => "alpha",
      "beta_change" => "beta",
      "recent_change" => "beta",
      "stable_change" => "stable",
      "conceptual_change" => "conceptual",
      "permanent_change" => "permanent",
      "never_change" => "never",
    )
    write_plugin_settings("plugin_alpha_change" => "alpha")
    commit_shas[:recent] = commit(
      "DEV: Bump recent upcoming change (#456)",
      date: "2026-05-20T12:00:00Z",
      author_name: "Bob Example",
      author_email: "bob@example.com",
    )
  end

  after { FileUtils.remove_entry(repo_path) }

  describe "#report" do
    it "reports eligibility and git metadata", :aggregate_failures do
      records = report.report.index_by { |record| record.fetch(:name) }

      expect(records.fetch("experimental_change")).to include(
        settings_path: "config/site_settings.yml",
        current_status: "experimental",
        next_status: "alpha",
        eligible: true,
        eligibility_reason: "status_unchanged_for_14_days",
        last_status_change_commit: commit_shas[:original],
        original_commit: commit_shas[:original],
        original_author_name: "Alice Example",
        original_author_email: "alice@example.com",
        original_pr_number: "123",
        branch: "dev/upcoming-change-status-bump/experimental_change",
        title: "FEATURE: Bump experimental_change upcoming change to alpha",
        pr_label: "upcoming-change",
      )
      expect(records.fetch("experimental_change").fetch(:pr_body)).to include(
        "<!-- upcoming-change-status-pr:experimental_change -->",
        "This automated PR moves `experimental_change` from `experimental` to `alpha`",
        "Original PR: #123",
      )
      expect(records.fetch("alpha_change")).to include(
        current_status: "alpha",
        next_status: "beta",
        eligible: true,
      )
      expect(records.fetch("beta_change")).to include(
        current_status: "beta",
        next_status: "stable",
        eligible: true,
      )
      recent_change = records.fetch("recent_change")
      expect(recent_change).to include(
        current_status: "beta",
        next_status: "stable",
        eligible: false,
        eligibility_reason: "status_changed_recently",
        last_status_change_commit: commit_shas[:recent],
        days_since_status_change: 5,
      )
      expect(Time.iso8601(recent_change.fetch(:last_status_change_date))).to eq(
        Time.iso8601("2026-05-20T12:00:00Z"),
      )
      expect(records.fetch("stable_change")).to include(
        current_status: "stable",
        next_status: nil,
        eligible: false,
        eligibility_reason: "terminal_status",
      )
      expect(records.fetch("conceptual_change")).to include(
        current_status: "conceptual",
        eligible: false,
        eligibility_reason: "terminal_status",
      )
      expect(records.fetch("permanent_change")).to include(
        current_status: "permanent",
        eligible: false,
        eligibility_reason: "terminal_status",
      )
      expect(records.fetch("never_change")).to include(
        current_status: "never",
        eligible: false,
        eligibility_reason: "terminal_status",
      )
      expect(records.fetch("plugin_alpha_change")).to include(
        settings_path: "plugins/chat/config/settings.yml",
        current_status: "alpha",
        next_status: "beta",
        eligible: true,
        original_commit: commit_shas[:original],
      )
    end
  end

  describe "#apply" do
    it "updates only the target setting file" do
      report.apply("plugin_alpha_change")

      metadata =
        described_class::MetadataLoader.from_file(
          File.join(repo_path, "plugins/chat/config/settings.yml"),
          strict: true,
        )

      expect(metadata.transform_values { |value| value[:status].to_s }).to include(
        plugin_alpha_change: "beta",
      )
      expect(File.read(File.join(repo_path, "config/site_settings.yml"))).to include(
        "  alpha_change:\n    default: false\n    client: true\n    hidden: true\n    upcoming_change:\n      status: alpha\n",
      )
    end
  end

  describe described_class::SourceStatusUpdater do
    it "raises when the status line cannot be edited" do
      settings_file = File.join(repo_path, "config/site_settings.yml")
      File.write(settings_file, <<~YAML)
          experimental:
            malformed_change:
              upcoming_change:
                status: "alpha beta"
        YAML

      updater = described_class.new(settings_file:)

      expect {
        updater.update!(change_name: "malformed_change", next_status: "beta")
      }.to raise_error(RuntimeError, /Could not parse status line/)
    end
  end

  def git(*args, env: {})
    stdout, stderr, status = Open3.capture3(env, "git", "-C", repo_path, *args)
    raise "git #{args.join(" ")} failed: #{stderr}" if !status.success?

    stdout
  end

  def commit(message, date:, author_name:, author_email:)
    git("add", ".")
    git(
      "commit",
      "-m",
      message,
      env: {
        "GIT_AUTHOR_DATE" => date,
        "GIT_COMMITTER_DATE" => date,
        "GIT_AUTHOR_NAME" => author_name,
        "GIT_AUTHOR_EMAIL" => author_email,
        "GIT_COMMITTER_NAME" => "Discourse CI",
        "GIT_COMMITTER_EMAIL" => "ci@ci.invalid",
      },
    )
    git("rev-parse", "HEAD").strip
  end

  def write_settings(statuses)
    FileUtils.mkdir_p(File.join(repo_path, "config"))
    File.write(File.join(repo_path, "config/site_settings.yml"), "experimental:\n")

    File.open(File.join(repo_path, "config/site_settings.yml"), "a") do |file|
      statuses.each do |name, status|
        file.write("  #{name}:\n")
        file.write("    default: false\n")
        file.write("    client: true\n")
        file.write("    hidden: true\n")
        file.write("    upcoming_change:\n")
        file.write("      status: #{status}\n")
        file.write("      impact: \"feature,all_members\"\n")
        file.write("      learn_more_url: \"https://meta.discourse.org/t/-/123\"\n")
      end
    end
  end

  def write_plugin_settings(statuses)
    FileUtils.mkdir_p(File.join(repo_path, "plugins/chat/config"))
    File.write(File.join(repo_path, "plugins/chat/config/settings.yml"), "chat:\n")

    File.open(File.join(repo_path, "plugins/chat/config/settings.yml"), "a") do |file|
      statuses.each do |name, status|
        file.write("  #{name}:\n")
        file.write("    default: false\n")
        file.write("    client: true\n")
        file.write("    hidden: true\n")
        file.write("    upcoming_change:\n")
        file.write("      status: #{status}\n")
        file.write("      impact: \"feature,all_members\"\n")
        file.write("      learn_more_url: \"https://meta.discourse.org/t/-/123\"\n")
      end
    end
  end
end
