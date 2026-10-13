# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions do
  fab!(:decision_model)

  let(:questions) do
    [
      { type: "yes_no", name: "spam", instructions: "Is this spam?" },
      {
        type: "choice",
        name: "team",
        instructions: "Who handles it?",
        choices: {
          "billing" => nil,
          "returns" => nil,
        },
      },
      { type: "score", name: "severity", instructions: "How bad?", levels: %w[low high] },
    ]
  end

  before { enable_current_plugin }

  describe ".with_canned_answers" do
    it "answers calls without hitting the network and records them" do
      described_class.with_canned_answers(
        spam: 0.93,
        team: "billing",
        severity: {
          low: 0.25,
          high: 0.75,
        },
      ) do |canned|
        result = decision_model.decide("Buy now!", questions:, feature_name: "test")

        expect(result["spam"]).to be_yes
        expect(result["team"]).to have_attributes(choice: "billing", confidence: 1.0)
        expect(result["severity"]).to have_attributes(level: "high", score: 0.75)
        expect(canned.calls.map { |call| call[:state] }).to eq(["Buy now!"])
      end
    end

    it "supports refusals and errors" do
      described_class.with_canned_answers(spam: :refusal, team: "returns", severity: "low") do
        result = decision_model.decide("Buy now!", questions:, feature_name: "test")
        expect(result["spam"]).to be_refusal
      end

      error = DiscourseAi::Decisions::InferenceError.new("down", http_status: 503)
      described_class.with_canned_answers(error) do
        expect {
          decision_model.decide("Buy now!", questions:, feature_name: "test")
        }.to raise_error(error)
      end
    end

    it "fails loudly on missing or unused canned answers" do
      expect {
        described_class.with_canned_answers(spam: 0.1) do
          decision_model.decide("Buy now!", questions:, feature_name: "test")
        end
      }.to raise_error(ArgumentError, /No canned answer for question "team"/)

      expect {
        described_class.with_canned_answers(spam: 0.1, team: "billing", severity: "low", typo: 1) do
          decision_model.decide("Buy now!", questions:, feature_name: "test")
        end
      }.to raise_error(ArgumentError, /never asked for: typo/)
    end
  end
end
