# frozen_string_literal: true

RSpec.describe LlmFeatureCreditCost do
  fab!(:llm_model)

  describe "validations" do
    it "requires llm_model_id" do
      cost = LlmFeatureCreditCost.new(feature_name: "test", credits_per_token: 1.0)
      expect(cost).not_to be_valid
      expect(cost.errors[:llm_model_id]).to be_present
    end

    it "requires feature_name" do
      cost = LlmFeatureCreditCost.new(llm_model: llm_model, credits_per_token: 1.0)
      expect(cost).not_to be_valid
      expect(cost.errors[:feature_name]).to be_present
    end

    it "requires unique feature_name per llm_model" do
      Fabricate(:llm_feature_credit_cost, llm_model: llm_model, feature_name: "test")
      cost =
        LlmFeatureCreditCost.new(llm_model: llm_model, feature_name: "test", credits_per_token: 2.0)
      expect(cost).not_to be_valid
      expect(cost.errors[:feature_name]).to be_present
    end

    it "requires credits_per_token to be non-negative" do
      cost =
        LlmFeatureCreditCost.new(
          llm_model: llm_model,
          feature_name: "test",
          credits_per_token: -1.0,
        )
      expect(cost).not_to be_valid
      expect(cost.errors[:credits_per_token]).to be_present
    end

    it "allows credits_per_token to be 0" do
      cost =
        LlmFeatureCreditCost.new(
          llm_model: llm_model,
          feature_name: "spam_detection",
          credits_per_token: 0.0,
        )
      expect(cost).to be_valid
    end
  end

  describe ".credit_cost_for" do
    it "returns specific cost when feature exists" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "ai_helper",
        credits_per_token: 2.5,
      )

      expect(LlmFeatureCreditCost.credit_cost_for(llm_model, "ai_helper")).to eq(2.5)
    end

    it "returns default cost when feature not found but default exists" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "default",
        credits_per_token: 1.5,
      )

      expect(LlmFeatureCreditCost.credit_cost_for(llm_model, "unknown_feature")).to eq(1.5)
    end

    it "returns 1.0 when neither feature nor default exists" do
      expect(LlmFeatureCreditCost.credit_cost_for(llm_model, "unknown_feature")).to eq(1.0)
    end

    it "returns 1.0 when llm_model is nil" do
      expect(LlmFeatureCreditCost.credit_cost_for(nil, "ai_helper")).to eq(1.0)
    end

    it "returns 1.0 when feature_name is blank" do
      expect(LlmFeatureCreditCost.credit_cost_for(llm_model, nil)).to eq(1.0)
      expect(LlmFeatureCreditCost.credit_cost_for(llm_model, "")).to eq(1.0)
    end
  end

  describe ".calculate_credit_cost" do
    it "calculates cost correctly" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "ai_helper",
        credits_per_token: 2.0,
      )

      expect(LlmFeatureCreditCost.calculate_credit_cost(llm_model, "ai_helper", 100)).to eq(200)
    end

    it "rounds up to nearest integer" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "ai_helper",
        credits_per_token: 1.5,
      )

      expect(LlmFeatureCreditCost.calculate_credit_cost(llm_model, "ai_helper", 100)).to eq(150)
      expect(LlmFeatureCreditCost.calculate_credit_cost(llm_model, "ai_helper", 101)).to eq(152)
    end

    it "handles fractional credits_per_token" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "ai_helper",
        credits_per_token: 0.5,
      )

      expect(LlmFeatureCreditCost.calculate_credit_cost(llm_model, "ai_helper", 100)).to eq(50)
    end

    it "returns 0 for spam_detection with 0 cost" do
      Fabricate(
        :llm_feature_credit_cost,
        llm_model: llm_model,
        feature_name: "spam_detection",
        credits_per_token: 0.0,
      )

      expect(LlmFeatureCreditCost.calculate_credit_cost(llm_model, "spam_detection", 100)).to eq(0)
    end
  end
end
