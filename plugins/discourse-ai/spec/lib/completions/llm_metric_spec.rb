# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::LlmMetric do
  fab!(:llm_model)

  describe ".record" do
    it "does not raise an error when DiscoursePrometheus is not defined" do
      expect do
        described_class.record(
          llm_model: llm_model,
          feature_name: "test_feature",
          request_tokens: 100,
          response_tokens: 50,
          duration_ms: 1500,
          status: :success,
        )
      end.not_to raise_error
    end

    it "accepts nil feature_name" do
      expect do
        described_class.record(
          llm_model: llm_model,
          feature_name: nil,
          request_tokens: 100,
          response_tokens: 50,
          duration_ms: 1500.0,
          status: :success,
        )
      end.not_to raise_error
    end

    it "accepts error status" do
      expect do
        described_class.record(
          llm_model: llm_model,
          feature_name: "test_feature",
          request_tokens: 0,
          response_tokens: 0,
          duration_ms: 500.0,
          status: :error,
        )
      end.not_to raise_error
    end
  end
end
