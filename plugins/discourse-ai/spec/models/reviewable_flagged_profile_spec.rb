# frozen_string_literal: true

RSpec.describe ReviewableFlaggedProfile do
  describe "#perform" do
    before do
      enable_current_plugin
      enable_dsa_reporting
    end

    it "keeps a member's flag with a triage marker out of AI triage and records human detection" do
      moderator = Fabricate(:moderator)
      owner = Fabricate(:user)
      owner.user_profile.update!(bio_raw: "Reported biography")
      report = Fabricate(:reviewable_flagged_profile, target: owner.user_profile)
      report.add_score(
        Fabricate(:user),
        ReviewableScore.types[:notify_moderators],
        reason: :profile_flag_message,
        context: "discourse_ai:triage_automation:1",
      )

      expect(Reviewable.list_for(moderator)).to include(report)
      expect(Reviewable.list_for(moderator, type: "discourse_ai:triage")).not_to include(report)
      expect(
        Reviewable.list_for(moderator, additional_filters: { ai_triage_automation_id: 1 }),
      ).not_to include(report)

      report.perform(moderator, :remove_profile_content)
      expect(report.dsa_statement_of_records.sole.payload["automated_detection"]).to eq("No")
    end
  end
end
