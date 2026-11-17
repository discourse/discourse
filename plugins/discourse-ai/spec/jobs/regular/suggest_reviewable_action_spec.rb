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
    DiscourseAi::Decisions.with_canned_answers(action: actions.first) do |canned|
      2.times { described_class.new.execute(reviewable_id: reviewable.id) }
      expect(canned.calls.size).to eq(1)
      call = canned.calls.first
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
