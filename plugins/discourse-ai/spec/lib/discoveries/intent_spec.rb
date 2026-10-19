# frozen_string_literal: true

RSpec.describe DiscourseAi::Discoveries::Intent do
  fab!(:user)
  fab!(:decision_model)

  before { enable_current_plugin }

  describe ".decision_model" do
    it "is the model chosen in settings" do
      SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id

      expect(described_class.decision_model).to eq(decision_model)
    end

    it "is nil when none is chosen" do
      expect(described_class.decision_model).to be_nil
    end
  end

  describe "#call" do
    subject(:intent) { described_class.new(user:, decision_model:) }

    it "returns the model's choice and its probability" do
      DiscourseAi::Decisions.with_canned_answers(
        intent: {
          "answer" => 0.8,
          "lookup" => 0.2,
        },
      ) do |canned|
        expect(intent.call("how do I reset my password")).to eq(intent: "answer", probability: 0.8)
        expect(canned.calls.sole).to include(
          state: {
            query: "how do I reset my password",
          },
          feature_name: "ai_search_intent",
          user:,
        )
      end
    end

    it "returns nil when the model refuses" do
      DiscourseAi::Decisions.with_canned_answers(intent: :refusal) do
        expect(intent.call("password")).to be_nil
      end
    end

    it "returns nil without a decision model" do
      expect(described_class.new(user:, decision_model: nil).call("password")).to be_nil
    end

    it "returns nil when the request fails" do
      stub_request(:post, decision_model.url).to_return(status: 500, body: "")

      expect(intent.call("password")).to be_nil
    end
  end
end
