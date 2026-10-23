# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions do
  fab!(:decision_model)
  fab!(:user)

  let(:questions) do
    [
      { name: "spam", type: "yes_no", instructions: "Spam?" },
      { name: "team", type: "choice", instructions: "Who?", choices: %w[billing returns] },
      { name: "severity", type: "score", instructions: "How bad?", levels: %w[low high] },
    ]
  end

  before { enable_current_plugin }

  describe ".with_canned_answers" do
    it "returns value objects, records calls across threads, and creates no audit or usage rows" do
      described_class.with_canned_answers(
        spam: 1,
        team: "billing",
        severity: {
          "low" => 0.25,
          "high" => 0.75,
        },
        unused: true,
      ) do |canned|
        result =
          Thread
            .new { decision_model.decide("Buy now!", questions:, user:, feature_name: "test") }
            .value
        expect(result).to be_a(DiscourseAi::Decisions::Result)
        expect(result["spam"].to_h).to eq(type: "yes_no", probability: 1.0)
        expect(result[:team]).to have_attributes(choice: "billing", confidence: 1.0)
        expect(result["severity"]).to have_attributes(
          score: 0.75,
          level: "high",
          probabilities: {
            "low" => 0.25,
            "high" => 0.75,
          },
        )
        expect(result.to_h[:answers]["team"]).to eq(result["team"].to_h)
        expect { result["unknown"] }.to raise_error(KeyError)
        expect(canned.calls).to contain_exactly(
          state: "Buy now!",
          questions: all(be_a(DiscourseAi::Decisions::Question)),
          user:,
          feature_name: "test",
          images: [],
        )
        expect(AiApiAuditLog.count).to eq(0)
        expect(AiApiRequestStat.count).to eq(0)
      end
    end

    it "supports boolean predicates, distributions, labels and refusals" do
      [true, false].each do |value|
        described_class.with_canned_answers(
          spam: value,
          team: {
            "returns" => 0.8,
            "billing" => 0.2,
          },
          severity: "low",
        ) do
          result = decision_model.decide("Hello", questions:, feature_name: "test")
          expect(result["spam"].probability).to eq(value ? 1.0 : 0.0)
          expect(result["team"].choice).to eq("returns")
          expect(result["severity"]).to have_attributes(score: 0.0, level: "low")
        end
      end
      described_class.with_canned_answers(spam: :refusal, team: :refusal, severity: :refusal) do
        result = decision_model.decide("Hello", questions:, feature_name: "test")
        expect(result.refusals.map(&:name)).to eq(%w[spam team severity])
        expect(result["spam"].to_h).to eq(type: "refusal", reason: nil)
      end
    end

    it "resets after exceptions and rejects nesting without clearing the outer block" do
      expect { described_class.with_canned_answers { raise "failed" } }.to raise_error("failed")
      expect(DiscourseAi::Decisions::CannedAnswers.current).to be_nil
      described_class.with_canned_answers(spam: 0.1) do |outer|
        expect { described_class.with_canned_answers {} }.to raise_error(ArgumentError, /nested/)
        expect(DiscourseAi::Decisions::CannedAnswers.current).to equal(outer)
        expect { decision_model.decide("Hello", questions:, feature_name: "test") }.to raise_error(
          ArgumentError,
          /No canned answer for question "team"/,
        )
        expect { decision_model.decide("", questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::InvalidRequest,
        )
      end
      expect(DiscourseAi::Decisions::CannedAnswers.current).to be_nil
    end

    it "rejects invalid canned probabilities and distributions" do
      [
        { spam: -0.1 },
        { team: "other" },
        { team: {} },
        { team: { billing: 2 } },
        { severity: { low: Float::INFINITY } },
      ].each do |overrides|
        described_class.with_canned_answers(
          **{ spam: true, team: "billing", severity: "low" }.merge(overrides),
        ) do
          expect {
            decision_model.decide("Hello", questions:, feature_name: "test")
          }.to raise_error(ArgumentError, /Invalid canned/)
        end
      end
    end
  end
end
