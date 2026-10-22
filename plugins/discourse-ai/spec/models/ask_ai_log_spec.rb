# frozen_string_literal: true

RSpec.describe AskAiLog do
  describe "#record_judgement!" do
    fab!(:user)

    let(:ask_log) { AskAiLog.create!(user:, query: "password reset", asked_at: Time.current) }

    before { enable_current_plugin }

    it "records the scope and the decision model's verdicts" do
      judgement =
        DiscourseAi::Discoveries::Intent::Judgement.new(
          intent: "lookup",
          probability: 0.7,
          scope: "site",
          scope_probability: 0.9,
        )

      ask_log.record_judgement!(scope: "topic:12", judgement:)

      expect(ask_log.reload).to have_attributes(
        ask_scope: "topic:12",
        ask_intent_model: "lookup",
        ask_intent_probability: 0.7,
        ask_scope_model: "site",
        ask_scope_probability: 0.9,
      )
    end

    it "records the scope alone when nothing was judged" do
      ask_log.record_judgement!(scope: "topic:12", judgement: nil)

      expect(ask_log.reload).to have_attributes(
        ask_scope: "topic:12",
        ask_intent_model: "",
        ask_intent_probability: 0,
        ask_scope_model: "",
        ask_scope_probability: 0,
      )
    end
  end
end
