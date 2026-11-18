# frozen_string_literal: true

RSpec.describe Jobs::SuggestReviewableAction do
  fab!(:decision_model)
  fab!(:reviewable, :reviewable_queued_post_topic)

  before do
    enable_current_plugin
    SiteSetting.ai_reviewable_action_suggestions_enabled = true
    SiteSetting.ai_reviewable_action_decision_model = decision_model.id.to_s
  end

  let(:actions) { reviewable.actions_for(Discourse.system_user.guardian).to_a.map(&:action_name) }

  it "sends the queued content and available choices and records a confident answer once" do
    SiteSetting.title = "Repair café"
    SiteSetting.site_description = "A forum for repairing household appliances."

    DiscourseAi::Decisions.with_canned_answers(action: actions.first) do |canned|
      2.times { described_class.new.execute(reviewable_id: reviewable.id) }
      expect(canned.calls.size).to eq(1)
      call = canned.calls.first
      expect(call[:questions].first.instructions).to include(
        SiteSetting.title,
        SiteSetting.site_description,
      )
      expect(call[:state]).not_to have_key(:forum)
      expect(call[:questions].first.choices).to match_array(actions)
      expect(call[:state].dig(:item, "raw")).to eq(reviewable.payload["raw"])
    end

    expect(AiReviewableSuggestion.find_by!(reviewable:)).to have_attributes(
      action_name: actions.first,
      confidence: 1.0,
      decision_model: decision_model,
    )
    expect(reviewable.reload).to be_pending
  end

  it "explains the account action alongside the suspect profile and reading history" do
    bio = "Wholesale loans! Contact offers@example.org for a quote."
    item = Fabricate(:suspect_user_reviewable, payload: { bio: bio })
    item.target.update!(created_at: 2.days.ago)
    item.target.user_stat.update!(posts_read_count: 1)

    DiscourseAi::Decisions.with_canned_answers(action: "user-delete_user_block") do |canned|
      described_class.new.execute(reviewable_id: item.id)
      call = canned.calls.sole
      expect(call[:questions].sole.instructions).to include(
        "prefer user-delete_user_block",
        I18n.t("reviewables.actions.reject_user.block.description"),
      )
      expect(call[:state][:account]).to include(age_days: 2, posts_read: 1)
      expect(call[:state].dig(:item, "bio")).to eq(bio)
      expect(call[:state][:flags].sole[:reason]).to eq("suspect_user")
    end
    expect(AiReviewableSuggestion.find_by!(reviewable: item).action_name).to eq(
      "user-delete_user_block",
    )
  end

  it "gives the model the fast-typing reason and the queued reply to evaluate together" do
    item = Fabricate(:reviewable_queued_post)
    item.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      reason: :fast_typer,
    )

    DiscourseAi::Decisions.with_canned_answers(action: :refusal) do |canned|
      described_class.new.execute(reviewable_id: item.id)
      call = canned.calls.sole
      expect(call[:state][:flags].sole[:reason]).to eq("fast_typer")
      expect(call[:state].dig(:item, "raw")).to eq(item.payload["raw"])
      expect(call[:questions].sole.instructions).to include("prefer delete_user_block")
    end
  end

  it "provides the spam flag and flagged post with the post-specific account action" do
    post = Fabricate(:post)
    reason =
      I18n.t("discourse_ai.spam_detection.flag_reason", url: "/admin/plugins/discourse-ai/ai-spam")
    item =
      PostActionCreator
        .new(
          Discourse.system_user,
          post,
          PostActionType.types[:spam],
          reason:,
          queue_for_review: true,
        )
        .perform
        .reviewable

    DiscourseAi::Decisions.with_canned_answers(action: :refusal) do |canned|
      described_class.new.execute(reviewable_id: item.id)
      call = canned.calls.sole
      expect(call[:state][:flags].sole).to include(type: :spam, reason:)
      expect(call[:state][:post]).to eq(post.raw)
      expect(call[:questions].sole.instructions).to include("prefer post-delete_user_block")
    end
  end

  it "omits the account recommendation when blocking is unavailable" do
    post = Fabricate(:post)
    item =
      PostActionCreator.create(
        Fabricate(:user, trust_level: TrustLevel[3]),
        post,
        :inappropriate,
      ).reviewable
    DiscourseAi::Decisions.with_canned_answers(action: :refusal) do |canned|
      described_class.new.execute(reviewable_id: item.id)
      question = canned.calls.sole[:questions].sole
      expect(question.choices).not_to include("post-delete_user_block")
      expect(question.instructions).not_to include("blocks its email and IP address")
    end
  end

  it "enqueues suggestions only when configured" do
    Jobs.run_later!
    expect { DiscourseEvent.trigger(:reviewable_created, reviewable) }.to change {
      described_class.jobs.size
    }.by(1)
    expect(described_class.jobs.last["args"].first["reviewable_id"]).to eq(reviewable.id)

    SiteSetting.ai_reviewable_action_decision_model = ""
    expect { DiscourseEvent.trigger(:reviewable_created, reviewable) }.not_to change {
      described_class.jobs.size
    }
  end

  it "skips new items and queued jobs when an admin disables suggestions" do
    SiteSetting.ai_reviewable_action_suggestions_enabled = false
    Jobs.run_later!
    expect { DiscourseEvent.trigger(:reviewable_created, reviewable) }.not_to change {
      described_class.jobs.size
    }
    DiscourseAi::Decisions.with_canned_answers do |canned|
      described_class.new.execute(reviewable_id: reviewable.id)
      expect(canned.calls).to be_empty
    end
  end

  it "skips uncertain answers and refusals" do
    [{ actions.first => 0.8, actions.second => 0.2 }, :refusal].each do |answer|
      DiscourseAi::Decisions.with_canned_answers(action: answer) do
        expect { described_class.new.execute(reviewable_id: reviewable.id) }.not_to change(
          AiReviewableSuggestion,
          :count,
        )
      end
    end
  end
end
