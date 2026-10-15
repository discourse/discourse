# frozen_string_literal: true

RSpec.describe ReviewablePost do
  describe "#perform" do
    before do
      enable_current_plugin
      freeze_time
      SiteSetting.dsa_reporting_enabled = true
    end

    it "records automatic detection when a moderator deletes a post queued for review by AI triage" do
      post = Fabricate(:post)
      reviewable =
        ReviewablePost.needs_review!(
          target: post,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
        )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "#{DiscourseAi::Automation::TRIAGE_AUTOMATION_SCORE_CONTEXT_PREFIX}123",
      )

      expect { reviewable.perform(Fabricate(:admin), :reject_and_delete) }.to change(
        DsaStatementOfRecord,
        :count,
      ).by(1)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

      expect(statement.payload).to eq(
        "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
        "decision_facts" => "The post was rejected and removed.",
        "source_type" => "SOURCE_VOLUNTARY",
        "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
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
