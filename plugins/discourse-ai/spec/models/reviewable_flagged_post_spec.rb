# frozen_string_literal: true

RSpec.describe ReviewableFlaggedPost do
  describe "#perform" do
    before do
      enable_current_plugin
      freeze_time
      SiteSetting.dsa_reporting_enabled = true
    end

    it "records automatic detection when a moderator deletes a post queued for review by AI triage" do
      reviewable = Fabricate(:reviewable_flagged_post)
      post = reviewable.target
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:spam],
        context: "#{DiscourseAi::Automation::TRIAGE_AUTOMATION_SCORE_CONTEXT_PREFIX}123",
      )

      expect { reviewable.perform(Fabricate(:admin), :delete_and_agree) }.to change(
        DsaStatementOfRecord,
        :count,
      ).by(1)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

      expect(statement.payload).to eq(
        "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
        "source_type" => "SOURCE_VOLUNTARY",
        "automated_detection" => "Yes",
        "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
        "content_type" => ["CONTENT_TYPE_TEXT"],
        "content_date" => post.created_at.to_date.iso8601,
        "application_date" => Date.current.iso8601,
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      )
    end
  end
end
