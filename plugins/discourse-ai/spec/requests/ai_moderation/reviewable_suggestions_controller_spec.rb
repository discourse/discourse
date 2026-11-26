# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::ReviewableSuggestionsController do
  fab!(:moderator)
  fab!(:decision_model)
  fab!(:post)
  fab!(:reviewable) do
    PostActionCreator.create(
      Fabricate(:user, trust_level: TrustLevel[3]),
      post,
      :inappropriate,
    ).reviewable
  end

  before do
    enable_current_plugin
    SiteSetting.ai_reviewable_action_suggestions_enabled = true
    SiteSetting.reviewable_claiming = "disabled"
  end

  def suggest(action_name, target: reviewable)
    AiReviewableSuggestion.create!(
      reviewable: target,
      decision_model:,
      action_name:,
      confidence: 0.96,
    )
  end

  describe "#index" do
    it "denies users who are not staff" do
      suggest("post-agree_and_hide")
      sign_in(Fabricate(:user))

      get "/review/bulk.json"

      expect(response.status).to eq(403)
    end

    it "denies staff when suggestions are disabled" do
      SiteSetting.ai_reviewable_action_suggestions_enabled = false
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.status).to eq(403)
    end

    it "lists pending items with the action that would be applied" do
      suggest("post-agree_and_hide")
      Fabricate(:reviewable_flagged_post)
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["total"]).to eq(1)
      expect(response.parsed_body["suggestions"]).to contain_exactly(
        a_hash_including(
          "id" => reviewable.id,
          "type" => "ReviewableFlaggedPost",
          "version" => reviewable.version,
          "title" => post.topic.title,
          "excerpt" => post.raw,
          "username" => post.user.username,
          "confidence" => 0.96,
          "action" => {
            "server_action" => "agree_and_hide",
            "label" => I18n.t("reviewables.actions.agree_and_hide.title"),
            "destructive" => false,
          },
        ),
      )
      expect(response.parsed_body["suggestions"].first).not_to have_key("blocked_reason")
    end

    it "omits handled items and suggestions for actions that are no longer available" do
      suggest("obsolete")
      handled = Fabricate(:reviewable_flagged_post, status: Reviewable.statuses[:approved])
      suggest("post-agree_and_hide", target: handled)
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.parsed_body["suggestions"]).to be_empty
    end

    it "omits refusals and filters by ai_reviewable_action_min_confidence" do
      refused = Fabricate(:reviewable_flagged_post)
      AiReviewableSuggestion.create!(
        reviewable: refused,
        decision_model:,
        action_name: nil,
        confidence: nil,
      )
      low_confidence =
        AiReviewableSuggestion.create!(
          reviewable:,
          decision_model:,
          action_name: "post-agree_and_hide",
          confidence: 0.75,
        )
      sign_in(moderator)

      get "/review/bulk.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["total"]).to eq(0)
      expect(response.parsed_body["suggestions"]).to be_empty

      get "/review.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body["reviewables"].map { |item| item["ai_suggested_action_name"] },
      ).to all(be_nil)

      SiteSetting.ai_reviewable_action_min_confidence = 0.75

      get "/review/bulk.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["total"]).to eq(1)
      expect(response.parsed_body["suggestions"].map { |item| item["id"] }).to contain_exactly(
        low_confidence.reviewable_id,
      )

      get "/review.json"
      expect(response.status).to eq(200)
      returned = response.parsed_body["reviewables"].find { |item| item["id"] == reviewable.id }
      expect(returned["ai_suggested_action_name"]).to eq("post-agree_and_hide")
    end

    it "blocks actions that need input from the moderator" do
      suggest("post-agree_and_edit")
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.parsed_body["suggestions"].first["blocked_reason"]).to eq("needs_input")
    end

    it "blocks unclaimed topics when claiming is required" do
      SiteSetting.reviewable_claiming = "required"
      suggest("post-agree_and_hide")
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.parsed_body["suggestions"].first["blocked_reason"]).to eq("must_claim")
    end

    it "blocks topics claimed by another user" do
      SiteSetting.reviewable_claiming = "optional"
      suggest("post-agree_and_hide")
      ReviewableClaimedTopic.create!(topic_id: reviewable.topic_id, user: Fabricate(:admin))
      sign_in(moderator)

      get "/review/bulk.json"

      expect(response.parsed_body["suggestions"].first["blocked_reason"]).to eq("claimed_by_other")
    end
  end
end
