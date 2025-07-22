# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new }

  fab!(:llm_model)

  let(:post_url) { "https://api.openai.com/v1/chat/completions" }
  let(:success_response) do
    {
      model: "gpt-4-turbo",
      usage: {
        max_prompt_tokens: 131_072,
      },
      choices: [
        { message: { role: "assistant", content: "test" }, finish_reason: "stop", index: 0 },
      ],
    }.to_json
  end

  let(:error_response) do
    { message: "API key error! Please check you have supplied the correct API key." }.to_json
  end

  before do
    stub_request(:post, post_url).to_return(status: 200, body: success_response, headers: {})
    SiteSetting.ai_summarization_model = "custom:#{llm_model.id}"
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#call" do
    it "does nothing if discourse-ai plugin disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(check).to be_chill_about_it
    end

    context "with discourse-ai plugin enabled for the site" do
      before { enable_current_plugin }

      it "returns a problem with an LLM model" do
        stub_request(:post, post_url).to_return(status: 403, body: error_response, headers: {})
        message =
          I18n.t(
            "dashboard.problem.ai_llm_status",
            {
              model_name: llm_model.display_name,
              url: "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}/edit",
            },
          )

        expect(described_class.new.call).to contain_exactly(
          have_attributes(
            identifier: "ai_llm_status",
            target: llm_model.id,
            priority: "high",
            message: message,
            details: {
              model_id: llm_model.id,
              model_name: llm_model.display_name,
              url: "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}/edit",
              error: JSON.parse(error_response)["message"],
            },
          ),
        )
      end

      it "does not return a problem if the LLM models are working" do
        stub_request(:post, post_url).to_return(status: 200, body: success_response, headers: {})
        expect(check).to be_chill_about_it
      end
    end
  end
end
