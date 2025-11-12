# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::HuggingFace do
  fab!(:hf_model)
  fab!(:user)

  before do
    enable_current_plugin
    AiApiAuditLog.destroy_all
  end

  let(:endpoint) { described_class.new(hf_model) }

  def generic_prompt(tools: [])
    DiscourseAi::Completions::Prompt.new(
      "You write words",
      messages: [{ type: :user, content: "write 3 words" }],
      tools: tools,
    )
  end

  def dialect(prompt = generic_prompt)
    DiscourseAi::Completions::Dialects::OpenAiCompatible.new(prompt, hf_model)
  end

  def with_scripted_responses(responses, llm_model: hf_model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      it "completes a trivial prompt and logs the response" do
        completion = "1. Serenity\n2. Laughter\n3. Adventure"
        prompt = generic_prompt
        open_ai_dialect = dialect(prompt)

        request_tokens = endpoint.prompt_size(open_ai_dialect.translate)
        response_tokens = hf_model.tokenizer_class.size(completion)
        usage = {
          prompt_tokens: request_tokens,
          completion_tokens: response_tokens,
          total_tokens: request_tokens + response_tokens,
        }

        with_scripted_responses([{ content: completion, usage: usage }]) do |scripted_http|
          result = endpoint.perform_completion!(open_ai_dialect, user)

          expect(result).to eq(completion)
          expect(scripted_http.last_request["messages"].first["content"]).to include(
            "write 3 words",
          )

          log = AiApiAuditLog.last
          expect(log.provider_id).to eq(endpoint.provider_id)
          expect(log.user_id).to eq(user.id)
          expect(log.raw_request_payload).to eq(scripted_http.last_request_raw.body)

          parsed_response = JSON.parse(log.raw_response_payload)
          expect(parsed_response.dig("choices", 0, "message", "content")).to eq(completion)
          expect(log.request_tokens).to eq(request_tokens)
          expect(log.response_tokens).to eq(response_tokens)
        end
      end
    end

    describe "when using streaming mode" do
      it "completes a trivial prompt and logs the response" do
        completion = "Mountain Tree Frog"
        prompt = generic_prompt
        streaming_dialect = dialect(prompt)
        request_tokens = endpoint.prompt_size(streaming_dialect.translate)

        cancel_manager = DiscourseAi::Completions::CancelManager.new
        buffered = +""

        with_scripted_responses([completion]) do
          endpoint.perform_completion!(
            streaming_dialect,
            user,
            cancel_manager: cancel_manager,
          ) do |partial|
            buffered << partial
            cancel_manager.cancel! if buffered.split(" ").length == 2
          end
        end

        log = AiApiAuditLog.last
        expect(log.provider_id).to eq(endpoint.provider_id)
        expect(log.user_id).to eq(user.id)
        expect(log.raw_request_payload).to be_present
        expect(log.raw_response_payload).to be_present
        expect(log.request_tokens).to eq(request_tokens)
        expect(log.response_tokens).to eq(hf_model.tokenizer_class.size(buffered))
      end
    end
  end
end
