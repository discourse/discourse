# frozen_string_literal: true

RSpec.describe LlmModel do
  before { enable_current_plugin }

  describe "api_key" do
    fab!(:llm_model, :seeded_model)

    before { ENV["DISCOURSE_AI_SEEDED_LLM_API_KEY_2"] = "blabla" }

    it "should use environment variable over database value if seeded LLM" do
      expect(llm_model.api_key).to eq("blabla")
    end
  end

  describe "#credit_system_enabled?" do
    fab!(:seeded_model)
    fab!(:regular_model, :llm_model)

    it "returns false for non-seeded models" do
      expect(regular_model.credit_system_enabled?).to be false
    end

    it "returns false for seeded models without credit allocation" do
      expect(seeded_model.credit_system_enabled?).to be false
    end

    it "returns true for seeded models with credit allocation" do
      Fabricate(:llm_credit_allocation, llm_model: seeded_model)
      expect(seeded_model.credit_system_enabled?).to be true
    end
  end

  describe "AWS Bedrock provider validation" do
    fab!(:bedrock_model, :bedrock_model)

    it "requires either access_key_id or role_arn" do
      # Should fail with neither
      bedrock_model.provider_params = { region: "us-east-1" }
      expect(bedrock_model.valid?).to be false
      expect(bedrock_model.errors[:base]).to include(
        I18n.t("discourse_ai.llm_models.bedrock_missing_auth"),
      )
    end

    it "is valid with access_key_id only" do
      bedrock_model.provider_params = { region: "us-east-1", access_key_id: "test_key" }
      expect(bedrock_model.valid?).to be true
    end

    it "is valid with role_arn only" do
      bedrock_model.provider_params = {
        region: "us-east-1",
        role_arn: "arn:aws:iam::123:role/test",
      }
      expect(bedrock_model.valid?).to be true
    end
  end
end
