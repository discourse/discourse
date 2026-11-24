# frozen_string_literal: true

RSpec.describe Jobs::ReviewableSuggestionsBackfill do
  fab!(:decision_model)

  before do
    enable_current_plugin
    SiteSetting.ai_reviewable_action_suggestions_enabled = true
    SiteSetting.ai_reviewable_action_decision_model = decision_model.id.to_s
  end

  def queue_post(created_at:, status: Reviewable.statuses[:pending])
    Fabricate(:reviewable_queued_post_topic, created_at:, status:)
  end

  def available_action_for(reviewable)
    reviewable.actions_for(Discourse.system_user.guardian).to_a.first.action_name
  end

  describe "#execute" do
    it "does nothing when the plugin, feature, or decision model is disabled" do
      item = queue_post(created_at: 1.day.ago)
      action_name = available_action_for(item)

      DiscourseAi::Decisions.with_canned_answers(action: action_name) do |canned|
        SiteSetting.discourse_ai_enabled = false
        described_class.new.execute({})

        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_reviewable_action_suggestions_enabled = false
        described_class.new.execute({})

        SiteSetting.ai_reviewable_action_suggestions_enabled = true
        SiteSetting.ai_reviewable_action_decision_model = ""
        described_class.new.execute({})

        expect(canned.calls).to be_empty
      end

      expect(AiReviewableSuggestion.count).to eq(0)
    end

    it "backfills pending reviewables newest-first and skips handled or already evaluated items" do
      older = queue_post(created_at: 3.days.ago)
      newer = queue_post(created_at: 1.day.ago)
      approved = queue_post(created_at: 2.days.ago, status: Reviewable.statuses[:approved])
      already_suggested = queue_post(created_at: 4.hours.ago)
      already_refused = queue_post(created_at: 2.hours.ago)

      action_name = available_action_for(newer)
      AiReviewableSuggestion.create!(
        reviewable: already_suggested,
        decision_model:,
        action_name:,
        confidence: 0.95,
      )
      AiReviewableSuggestion.create!(
        reviewable: already_refused,
        decision_model:,
        action_name: nil,
        confidence: nil,
      )

      DiscourseAi::Decisions.with_canned_answers(action: action_name) do |canned|
        described_class.new.execute({})

        expect(canned.calls.map { |call| call[:state].dig(:item, "raw") }).to eq(
          [newer.payload["raw"], older.payload["raw"]],
        )
      end

      expect(older.reload.ai_reviewable_suggestion).to be_present
      expect(newer.reload.ai_reviewable_suggestion).to be_present
      expect(approved.reload.ai_reviewable_suggestion).to be_nil
    end

    it "processes at most BATCH_SIZE items per run" do
      stub_const(described_class, :BATCH_SIZE, 2) do
        oldest = queue_post(created_at: 3.days.ago)
        middle = queue_post(created_at: 2.days.ago)
        newest = queue_post(created_at: 1.day.ago)
        action_name = available_action_for(newest)

        DiscourseAi::Decisions.with_canned_answers(action: action_name) do
          described_class.new.execute({})
          expect(newest.reload.ai_reviewable_suggestion).to be_present
          expect(middle.reload.ai_reviewable_suggestion).to be_present
          expect(oldest.reload.ai_reviewable_suggestion).to be_nil

          described_class.new.execute({})
          expect(oldest.reload.ai_reviewable_suggestion).to be_present
        end
      end
    end

    it "stops when credits are exhausted before starting or mid-batch" do
      seeded_model = Fabricate(:decision_model, id: -1)
      allocation =
        Fabricate(
          :decision_model_credit_allocation,
          decision_model: seeded_model,
          daily_credits: 100,
          daily_used: 100,
        )
      SiteSetting.ai_reviewable_action_decision_model = seeded_model.id.to_s

      first_item = queue_post(created_at: 2.days.ago)
      second_item = queue_post(created_at: 1.day.ago)
      action_name = available_action_for(second_item)

      DiscourseAi::Decisions.with_canned_answers(action: action_name) do |canned|
        described_class.new.execute({})
        expect(canned.calls).to be_empty
      end

      allocation.update!(daily_credits: 100)
      DecisionModelCreditDailyUsage.where(decision_model: seeded_model).delete_all

      Jobs::SuggestReviewableAction
        .any_instance
        .stubs(:execute)
        .with(reviewable_id: second_item.id)
        .raises(DiscourseAi::Decisions::CreditLimitExceeded.new("limit exceeded", allocation:))

      described_class.new.execute({})

      expect(first_item.reload.ai_reviewable_suggestion).to be_nil
      expect(second_item.reload.ai_reviewable_suggestion).to be_nil
    end

    it "continues past an isolated failure and aborts after MAX_CONSECUTIVE_FAILURES" do
      stub_const(described_class, :MAX_CONSECUTIVE_FAILURES, 2) do
        remaining = queue_post(created_at: 5.days.ago)
        third_fail = queue_post(created_at: 4.days.ago)
        second_fail = queue_post(created_at: 3.days.ago)
        succeeds = queue_post(created_at: 2.days.ago)
        first_fail = queue_post(created_at: 1.day.ago)

        error = DiscourseAi::Decisions::RequestFailed.new("temporary failure", retryable: false)
        action_name = available_action_for(succeeds)

        DiscourseAi::Decisions::Client
          .any_instance
          .stubs(:decide)
          .raises(error)
          .then
          .returns(
            DiscourseAi::Decisions::Result.new(
              answers: [
                DiscourseAi::Decisions::Answers::Choice.new(
                  name: "action",
                  choice: action_name,
                  probabilities: {
                    action_name => 0.95,
                  },
                  confidence: 0.95,
                ),
              ],
            ),
          )
          .then
          .raises(error)
          .then
          .raises(error)

        described_class.new.execute({})

        expect(first_fail.reload.ai_reviewable_suggestion).to be_nil
        expect(succeeds.reload.ai_reviewable_suggestion).to be_present
        expect(second_fail.reload.ai_reviewable_suggestion).to be_nil
        expect(third_fail.reload.ai_reviewable_suggestion).to be_nil
        expect(remaining.reload.ai_reviewable_suggestion).to be_nil
      end
    end
  end
end
