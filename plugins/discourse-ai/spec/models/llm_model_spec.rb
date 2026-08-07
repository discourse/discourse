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

  describe "Google Vertex AI provider validation" do
    def build_vertex_model(provider_params)
      Fabricate.build(
        :llm_model,
        provider: "google_vertex_ai",
        tokenizer: "DiscourseAi::Tokenizer::GeminiTokenizer",
        name: "google/gemini-3.5-flash",
        url: nil,
        api_key: nil,
        provider_params: provider_params,
      )
    end

    it "does not require a URL or API key" do
      model = build_vertex_model(project_id: "discourse-project", region: "global")

      expect(model).to be_valid
    end

    it "requires region and project_id" do
      model = build_vertex_model({})

      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(
        I18n.t("discourse_ai.llm_models.missing_provider_param", param: "region"),
        I18n.t("discourse_ai.llm_models.missing_provider_param", param: "project_id"),
      )
    end

    it "rejects regions that could redirect requests to another host" do
      model = build_vertex_model(project_id: "discourse-project", region: "evil.example/")

      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(
        I18n.t("discourse_ai.llm_models.invalid_provider_param", param: "region"),
      )
    end

    it "rejects project ids that don't match the GCP format" do
      model = build_vertex_model(project_id: "Bad Project!", region: "us-central1")

      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(
        I18n.t("discourse_ai.llm_models.invalid_provider_param", param: "project_id"),
      )
    end
  end

  describe "#estimated_cost_for_tokens" do
    it "calculates request, response, cache read, and cache write cost" do
      model =
        Fabricate.build(
          :llm_model,
          input_cost: 3.0,
          output_cost: 15.0,
          cached_input_cost: 0.3,
          cache_write_cost: 3.75,
        )

      cost =
        model.estimated_cost_for_tokens(
          request_tokens: 1_000_000,
          response_tokens: 100_000,
          cache_read_tokens: 10_000,
          cache_write_tokens: 1_000,
        )

      expect(cost).to eq(BigDecimal("4.50675"))
    end

    it "returns nil when no costs are configured" do
      model =
        Fabricate.build(
          :llm_model,
          input_cost: nil,
          output_cost: nil,
          cached_input_cost: nil,
          cache_write_cost: 0,
        )

      expect(
        model.estimated_cost_for_tokens(
          request_tokens: 1_000_000,
          response_tokens: 100_000,
          cache_read_tokens: 10_000,
          cache_write_tokens: 1_000,
        ),
      ).to be_nil
    end
  end

  describe "allowed_attachment_types" do
    it "normalizes markdown attachments to md" do
      model = Fabricate.build(:llm_model)
      model.allowed_attachment_types = %w[pdf markdown md htm text]

      expect(model.allowed_attachment_types).to eq(%w[pdf md html txt])
    end
  end
end
