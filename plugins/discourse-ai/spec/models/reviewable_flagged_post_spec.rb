# frozen_string_literal: true

RSpec.describe ReviewableFlaggedPost do
  describe "#perform" do
    before do
      enable_current_plugin
      freeze_time
      SiteSetting.dsa_reporting_enabled = true
    end

    it "records automatic detection when a moderator deletes spam detected by the spam bot" do
      AiModerationSetting.create!(setting_type: :spam, llm_model: Fabricate(:llm_model))
      SiteSetting.ai_spam_detection_enabled = true
      post = Fabricate(:post, user: Fabricate(:user, trust_level: TrustLevel[0]))
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ spam: true, reason: "spam detected" }],
      ) { DiscourseAi::AiModeration::SpamScanner.perform_scan(post) }
      reviewable = AiSpamLog.find_by!(post: post).reviewable
      SiteSetting.ai_spam_detection_enabled = false

      reviewable.perform(Fabricate(:admin), :delete_and_agree)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload).to include(
        "automated_detection" => "Yes",
        "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
      )
    end

    it "preserves manual detection for system spam flags when no scanner bot is configured" do
      SiteSetting.ai_spam_detection_user_id = ""
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.add_score(Discourse.system_user, ReviewableScore.types[:spam])

      reviewable.perform(Fabricate(:admin), :delete_and_agree)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["automated_detection"]).to eq("No")
    end

    it "records manual detection when a moderator deletes a post flagged as spam by a human" do
      DiscourseAi::AiModeration::SpamScanner.ensure_flagging_user!
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.add_score(Fabricate(:user), ReviewableScore.types[:spam])

      reviewable.perform(Fabricate(:admin), :delete_and_agree)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["automated_detection"]).to eq("No")
    end

    it "records manual detection for a nonspam flag from the configured spam flagger" do
      DiscourseAi::AiModeration::SpamScanner.ensure_flagging_user!
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.add_score(
        DiscourseAi::AiModeration::SpamScanner.flagging_user,
        ReviewableScore.types[:off_topic],
      )

      reviewable.perform(Fabricate(:admin), :delete_and_agree)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["automated_detection"]).to eq("No")
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
        "decision_facts" => "The flagged post was removed.",
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
