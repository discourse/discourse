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

  context "when a profile is reported again" do
    fab!(:reporter) { Fabricate(:trust_level_2, refresh_auto_groups: true) }
    fab!(:owner, :user)
    fab!(:profile_report) do
      owner.user_profile.update!(bio_raw: "First reported biography")
      Fabricate(:reviewable_flagged_profile, target: owner.user_profile, created_by: reporter)
    end

    before do
      SiteSetting.flaggable_user_profiles = true
      Jobs.run_later!
    end

    def reopen_profile_report
      profile_report.perform(Discourse.system_user, :dismiss_profile_flag)
      owner.user_profile.update!(bio_raw: "New biography")
      User::FlagProfile.call!(
        guardian: reporter.guardian,
        params: {
          username: owner.username,
          flag_type_id: PostActionType.types[:inappropriate],
        },
      )
    end

    it "replaces the previous suggestion using the new snapshot and pending flags" do
      DiscourseAi::Decisions.with_canned_answers(action: "user_profile-remove_profile_content") do
        described_class.new.execute(reviewable_id: profile_report.id)
      end
      expect(profile_report.reload.ai_reviewable_suggestion.action_name).to eq(
        "user_profile-remove_profile_content",
      )

      expect { reopen_profile_report }.to change { described_class.jobs.size }.by(1)
      expect(profile_report.reload.ai_reviewable_suggestion).to be_nil
      job_args = described_class.jobs.last.fetch("args").sole.symbolize_keys
      DiscourseAi::Decisions.with_canned_answers(
        action: "user_profile-dismiss_profile_flag",
      ) do |canned|
        described_class.new.execute(job_args)
        expect(canned.calls.sole[:state].dig(:item, "bio")).to eq(owner.user_profile.bio_raw)
        expect(canned.calls.sole[:state][:flags].sole[:type]).to eq(:inappropriate)
      end
      expect(profile_report.reload.ai_reviewable_suggestion.action_name).to eq(
        "user_profile-dismiss_profile_flag",
      )
    end

    it "clears the stale suggestion without queuing another when the plugin is disabled" do
      DiscourseAi::Decisions.with_canned_answers(action: "user_profile-remove_profile_content") do
        described_class.new.execute(reviewable_id: profile_report.id)
      end
      suggestion = profile_report.reload.ai_reviewable_suggestion
      expect(suggestion).to be_actionable

      SiteSetting.discourse_ai_enabled = false
      expect { reopen_profile_report }.not_to change { described_class.jobs.size }
      expect(AiReviewableSuggestion.exists?(suggestion.id)).to be(false)

      SiteSetting.discourse_ai_enabled = true
      expect(profile_report.reload).to be_pending
      expect(profile_report.ai_reviewable_suggestion).to be_nil
    end

    it "discards a suggestion if the profile is resolved and reported again during inference" do
      reopen = method(:reopen_profile_report)
      DiscourseAi::Decisions.with_canned_answers(
        action: "user_profile-remove_profile_content",
      ) do |canned|
        canned.define_singleton_method(:decide) do |**args|
          reopen.call
          super(**args)
        end
        described_class.new.execute(reviewable_id: profile_report.id)
      end

      expect(profile_report.reload).to be_pending
      expect(profile_report.ai_reviewable_suggestion).to be_nil
    end
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

  it "provides the post's full flag history and the post-specific account action" do
    post = Fabricate(:post)
    earlier_report =
      PostActionCreator.create(Fabricate(:trust_level_2), post, :inappropriate).reviewable
    earlier_report.perform(Discourse.system_user, :disagree)
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
      expect(call[:state][:flags]).to contain_exactly(
        a_hash_including(type: :inappropriate),
        a_hash_including(type: :spam, reason:),
      )
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

  it "records below-threshold answers once and reveals them if min confidence drops" do
    DiscourseAi::Decisions.with_canned_answers(
      action: {
        actions.first => 0.8,
        actions.second => 0.2,
      },
    ) do |canned|
      2.times { described_class.new.execute(reviewable_id: reviewable.id) }
      expect(canned.calls.size).to eq(1)
    end

    suggestion = AiReviewableSuggestion.find_by!(reviewable:)
    expect(suggestion).to have_attributes(
      action_name: actions.first,
      confidence: 0.8,
      decision_model:,
    )
    expect(suggestion).not_to be_actionable

    SiteSetting.ai_reviewable_action_min_confidence = 0.8
    expect(suggestion).to be_actionable
    expect(AiReviewableSuggestion.actionable).to contain_exactly(suggestion)
  end

  it "records refusals once so items are not re-evaluated" do
    DiscourseAi::Decisions.with_canned_answers(action: :refusal) do |canned|
      2.times { described_class.new.execute(reviewable_id: reviewable.id) }
      expect(canned.calls.size).to eq(1)
    end

    suggestion = AiReviewableSuggestion.find_by!(reviewable:)
    expect(suggestion).to have_attributes(action_name: nil, confidence: nil, decision_model:)
    expect(suggestion).not_to be_actionable
    expect(AiReviewableSuggestion.actionable).to be_empty
  end

  it "records a blank suggestion without calling the model when no actions are available" do
    ReviewableQueuedPost
      .any_instance
      .stubs(:actions_for)
      .returns(Reviewable::Actions.new(reviewable, Guardian.new))

    DiscourseAi::Decisions.with_canned_answers do |canned|
      described_class.new.execute(reviewable_id: reviewable.id)
      expect(canned.calls).to be_empty
    end

    suggestion = AiReviewableSuggestion.find_by!(reviewable:)
    expect(suggestion).to have_attributes(action_name: nil, confidence: nil, decision_model:)
    expect(suggestion).not_to be_actionable
  end

  it "skips without recording a row when credits are exhausted" do
    seeded_model = Fabricate(:decision_model, id: -1)
    Fabricate(
      :decision_model_credit_allocation,
      decision_model: seeded_model,
      daily_credits: 100,
      daily_used: 100,
    )
    SiteSetting.ai_reviewable_action_decision_model = seeded_model.id.to_s

    DiscourseAi::Decisions.with_canned_answers(action: actions.first) do |canned|
      expect { described_class.new.execute(reviewable_id: reviewable.id) }.not_to change(
        AiReviewableSuggestion,
        :count,
      )
      expect(canned.calls).to be_empty
    end
  end
end
