# frozen_string_literal: true

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new(target) }

  fab!(:llm_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

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

  let(:target) { llm_model.id }

  before do
    stub_request(:post, post_url).to_return(status: 200, body: success_response, headers: {})
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_persona = ai_persona.id
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

        expect(check).to have_a_problem
          .with_priority("high")
          .with_target(llm_model.id)
          .with_message(message)
      end

      it "does not return a problem if the LLM models are working" do
        stub_request(:post, post_url).to_return(status: 200, body: success_response, headers: {})
        expect(check).to be_chill_about_it
      end

      it "skips seeded LLMs" do
        SiteSetting.ai_summarization_enabled = false

        seeded_llm = Fabricate(:seeded_model)
        ai_persona_seeded = Fabricate(:ai_persona, default_llm_id: seeded_llm.id)
        SiteSetting.ai_summarization_persona = ai_persona_seeded.id
        SiteSetting.ai_summarization_enabled = true

        stub_request(:post, "https://cdck.test/").to_return(
          status: 403,
          body: error_response,
          headers: {
          },
        )
        expect(check).to be_chill_about_it
      end

      it "does not report problems for rate limit errors" do
        rate_limit_response = { message: "Rate limit exceeded. Please retry after 60s." }.to_json

        stub_request(:post, post_url).to_return(status: 429, body: rate_limit_response, headers: {})
        expect(check).to be_chill_about_it
      end

      it "does not report problems for 503 errors (service unavailable)" do
        service_unavailable_response = { message: "Service temporarily unavailable" }.to_json

        stub_request(:post, post_url).to_return(
          status: 503,
          body: service_unavailable_response,
          headers: {
          },
        )
        expect(check).to be_chill_about_it
      end

      it "reports problem for network timeout errors" do
        stub_request(:post, post_url).to_timeout

        expect(check).to have_a_problem.with_priority("high").with_target(llm_model.id)
      end

      it "reports problem for authentication errors" do
        stub_request(:post, post_url).to_return(status: 401, body: error_response, headers: {})

        expect(check).to have_a_problem.with_priority("high").with_target(llm_model.id)
      end
    end
  end
end
