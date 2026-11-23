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
      expect(response.parsed_body["next_offset"]).to be_nil
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

    it "pages past the first batch with an offset" do
      later = Fabricate(:reviewable_flagged_post, score: reviewable.score - 1)
      suggest("post-agree_and_hide")
      suggest("post-agree_and_hide", target: later)
      sign_in(moderator)

      stub_const(described_class, :LIMIT, 1) do
        get "/review/bulk.json"

        expect(response.parsed_body["suggestions"].map { |row| row["id"] }).to eq([reviewable.id])
        expect(response.parsed_body["next_offset"]).to eq(1)

        get "/review/bulk.json", params: { offset: 1 }

        expect(response.parsed_body["suggestions"].map { |row| row["id"] }).to eq([later.id])
        expect(response.parsed_body["next_offset"]).to be_nil
      end
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
