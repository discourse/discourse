# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe UpcomingChanges::StatusReport do
  subject(:report) do
    described_class.new(repo_path:, stale_after_days: 14, now: Time.iso8601("2026-05-26T00:00:00Z"))
  end

  let(:repo_path) { Dir.mktmpdir("upcoming-changes-status-report") }
  let(:repository) { UpcomingChangesStatusReportRepository.new(path: repo_path) }
  let(:commit_shas) { {} }

  before do
    repository.git("init")
    repository.git("config", "user.name", "Discourse CI")
    repository.git("config", "user.email", "ci@ci.invalid")

    repository.write_settings(
      statuses: {
        "experimental_change" => "experimental",
        "alpha_change" => "alpha",
        "beta_change" => "beta",
        "recent_change" => "alpha",
        "stable_change" => "stable",
        "conceptual_change" => "conceptual",
        "permanent_change" => "permanent",
        "never_change" => "never",
      },
    )
    repository.write_plugin_settings(statuses: { "plugin_alpha_change" => "alpha" })
    commit_shas[:original] = repository.commit(
      message: "FEATURE: Add upcoming changes (#123)",
      date: "2026-04-01T12:00:00Z",
      author_name: "Alice Example",
      author_email: "alice@example.com",
    )

    FileUtils.rm_rf(File.join(repo_path, "plugins/chat"))
    commit_shas[:plugin_removed] = repository.commit(
      message: "DEV: Remove plugin settings",
      date: "2026-04-15T12:00:00Z",
      author_name: "Alice Example",
      author_email: "alice@example.com",
    )

    repository.write_plugin_settings(statuses: { "plugin_alpha_change" => "alpha" })
    commit_shas[:plugin_restored] = repository.commit(
      message: "DEV: Restore plugin settings",
      date: "2026-04-20T12:00:00Z",
      author_name: "Alice Example",
      author_email: "alice@example.com",
    )

    repository.write_settings(
      statuses: {
        "experimental_change" => "experimental",
        "alpha_change" => "alpha",
        "beta_change" => "beta",
        "recent_change" => "beta",
        "stable_change" => "stable",
        "conceptual_change" => "conceptual",
        "permanent_change" => "permanent",
        "never_change" => "never",
      },
    )
    repository.write_plugin_settings(statuses: { "plugin_alpha_change" => "alpha" })
    commit_shas[:recent] = repository.commit(
      message: "DEV: Bump recent upcoming change (#456)",
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
        last_status_change_commit: commit_shas[:original],
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
end
