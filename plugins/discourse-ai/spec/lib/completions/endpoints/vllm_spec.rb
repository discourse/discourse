# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::Vllm do
  fab!(:an_llm_model, :vllm_model)
  fab!(:user)

  before do
    enable_current_plugin
    AiApiAuditLog.destroy_all
  end

  let(:llm) { DiscourseAi::Completions::Llm.proxy(an_llm_model) }
  let(:endpoint) { described_class.new(an_llm_model) }

  def with_scripted_responses(responses, model: an_llm_model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

  def generic_prompt(tools: [], tool_choice: nil)
    DiscourseAi::Completions::Prompt.new(
      "You write words",
      messages: [{ type: :user, content: "write 3 words" }],
      tools: tools,
      tool_choice: tool_choice,
    )
  end

  def dialect(prompt = generic_prompt)
    DiscourseAi::Completions::Dialects::OpenAiCompatible.new(prompt, llm_model)
  end

  def weather_tool
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: [
        { name: "location", type: "string", description: "the city name", required: true },
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
          required: true,
        },
      ],
    }
  end

  def tool_response
    <<~XML
      <function_calls>
      <invoke>
      <tool_name>get_weather</tool_name>
      <parameters>
      <location>Sydney</location>
      <unit>c</unit>
      </parameters>
      </invoke>
      </function_calls>
      should be ignored
    XML
  end

  def tool_invocation
    DiscourseAi::Completions::ToolCall.new(
      id: "tool_0",
      name: "get_weather",
      parameters: {
        location: "Sydney",
        unit: "c",
      },
    )
  end

  describe "tool support" do
    it "is able to invoke XML tools correctly" do
      xml = <<~XML
        <function_calls>
        <invoke>
        <tool_name>calculate</tool_name>
        <parameters>
        <expression>1+1</expression></parameters>
        </invoke>
        </function_calls>
        should be ignored
      XML

      tool = {
        name: "calculate",
        description: "calculate something",
        parameters: [
          {
            name: "expression",
            type: "string",
            description: "expression to calculate",
            required: true,
          },
        ],
      }

      expected =
        DiscourseAi::Completions::ToolCall.new(
          name: "calculate",
          id: "tool_0",
          parameters: {
            expression: "1+1",
          },
        )

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You a calculator",
          messages: [{ type: :user, id: "user1", content: "calculate 2758975 + 21.11" }],
          tools: [tool],
        )

      with_scripted_responses([xml]) do
        result = llm.generate(prompt, user: Discourse.system_user)
        expect(result).to eq(expected)
      end
    end
  end

  it "correctly accounts for tokens in non streaming mode" do
    body = "Random Number Generator Produces Smallest Possible Result"
    usage = { prompt_tokens: 146, completion_tokens: 10, total_tokens: 156 }

    with_scripted_responses([{ content: body, usage: usage }]) do
      result = llm.generate("generate a title", user: Discourse.system_user)

      expect(result).to eq("Random Number Generator Produces Smallest Possible Result")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(146)
      expect(log.response_tokens).to eq(10)
    end
  end

  it "can properly include usage in streaming mode" do
    completion =
      "Hello Sam. It's nice to meet you. Is there something I can help you with or would you like to chat?"
    usage = { prompt_tokens: 46, completion_tokens: 26, total_tokens: 72 }

    with_scripted_responses([{ content: completion, usage: usage }]) do
      streamed = []
      llm.generate("say hello", user: Discourse.system_user) { |partial| streamed << partial }

      expect(streamed.join).to eq(completion)

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(46)
      expect(log.response_tokens).to eq(26)
    end
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with tools" do
        it "returns a function invocation" do
          prompt = generic_prompt(tools: [weather_tool])
          open_ai_dialect = dialect(prompt)

          with_scripted_responses([tool_response]) do
            completion_response = endpoint.perform_completion!(open_ai_dialect, user)
            expect(completion_response).to eq(tool_invocation)
          end
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
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

          log = AiApiAuditLog.order(:id).last
          expect(log.provider_id).to eq(endpoint.provider_id)
          expect(log.request_tokens).to eq(request_tokens)
          expect(log.response_tokens).to eq(llm_model.tokenizer_class.size(buffered))
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          prompt = generic_prompt(tools: [weather_tool])
          open_ai_dialect = dialect(prompt)
          buffered = []

          with_scripted_responses([tool_response]) do
            endpoint.perform_completion!(open_ai_dialect, user) { |partial| buffered << partial }
          end

          expect(buffered).to eq([tool_invocation])
        end
      end
    end
  end
end
