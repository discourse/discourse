# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::DecisionMatcher do
  fab!(:decision_model)

  subject(:matcher) { described_class.new(decision_model) }

  before { enable_current_plugin }

  describe ".available? / .decision_model" do
    it "returns nil/false when unset and resolves the configured DecisionModel when set" do
      SiteSetting.inferred_concepts_match_decision_model = ""
      expect(described_class.decision_model).to be_nil
      expect(described_class).not_to be_available

      SiteSetting.inferred_concepts_match_decision_model = decision_model.id
      expect(described_class.decision_model).to eq(decision_model)
      expect(described_class).to be_available
    end
  end

  describe "#match" do
    fab!(:k8s) do
      Fabricate(
        :inferred_concept,
        name: "Kubernetes",
        description: "Container orchestration",
        aliases: %w[k8s kube],
        status: :active,
      )
    end
    fab!(:docker) { Fabricate(:inferred_concept, name: "Docker", status: :active) }
    fab!(:helm) { Fabricate(:inferred_concept, name: "Helm", status: :active) }
    fab!(:retired) { Fabricate(:inferred_concept, name: "Legacy VM", status: :retired) }

    it "evaluates yes_no questions with descriptions/aliases, marks highest as primary, and filters below threshold" do
      result =
        DiscourseAi::Decisions.with_canned_answers(c_0: 0.78, c_1: 0.91, c_2: 0.40) do |canned|
          output =
            matcher.match(
              "Deploying multi-container pods with Docker and Kubernetes",
              candidates: [k8s, docker, helm, retired],
            )

          questions = canned.calls.sole[:questions]
          expect(questions.size).to eq(3)
          expect(questions.first.type).to eq(:yes_no)
          expect(questions.first.instructions).to include("Kubernetes")
          expect(questions.first.instructions).to include("Container orchestration")
          expect(questions.first.instructions).to include("k8s, kube")
          output
        end

      expect(result[:all_refused]).to eq(false)
      expect(result[:matches]).to eq(
        [
          { concept_id: docker.id, relevance: 0.91, primary: true },
          { concept_id: k8s.id, relevance: 0.78, primary: false },
        ],
      )
    end

    it "caps questions at MAX_CANDIDATES and matches at MAX_MATCHES" do
      concepts =
        (1..17).map { |i| Fabricate(:inferred_concept, name: "Concept #{i}", status: :active) }
      canned_map = (0...15).index_by { |i| :"c_#{i}" }.transform_values { |i| 0.99 - (i * 0.01) }

      result =
        DiscourseAi::Decisions.with_canned_answers(**canned_map) do |canned|
          output = matcher.match("Long discussion covering many topics", candidates: concepts)
          expect(canned.calls.sole[:questions].size).to eq(described_class::MAX_CANDIDATES)
          output
        end

      expect(result[:matches].size).to eq(described_class::MAX_MATCHES)
      expect(result[:matches].first[:primary]).to eq(true)
      expect(result[:matches].drop(1).all? { |m| !m[:primary] }).to eq(true)
    end

    it "flags all_refused when every question returns a refusal" do
      result =
        DiscourseAi::Decisions.with_canned_answers(c_0: :refusal, c_1: :refusal) do
          matcher.match("Ambiguous discussion", candidates: [k8s, docker])
        end

      expect(result).to eq(matches: [], all_refused: true)
    end

    it "propagates CreditLimitExceeded" do
      decision_model.update!(id: -551)
      Fabricate(
        :decision_model_credit_allocation,
        decision_model: decision_model,
        daily_credits: 10,
      )
      DecisionModelCreditDailyUsage.increment_usage!(decision_model, 10)

      expect { matcher.match("Kubernetes deployments", candidates: [k8s]) }.to raise_error(
        DiscourseAi::Decisions::CreditLimitExceeded,
      )
    end
  end
end
