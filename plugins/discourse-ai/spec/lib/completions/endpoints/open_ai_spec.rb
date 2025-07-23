# frozen_string_literal: true

require_relative "endpoint_compliance"

class OpenAiMock < EndpointMock
  def response(content, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [content] }
      else
        { content: content }
      end

    {
      id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "gpt-3.5-turbo-0301",
      usage: {
        prompt_tokens: 8,
        completion_tokens: 12,
        total_tokens: 499,
      },
      choices: [
        { message: { role: "assistant" }.merge(message_content), finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: request_body(prompt, tool_call: tool_call))
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [delta] }
      else
        { content: delta }
      end

    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "gpt-3.5-turbo-0301",
      choices: [{ delta: message_content }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_raw(chunks, body_blk: nil)
    stub = WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")
    stub.with(body: body_blk) if body_blk
    stub.to_return(status: 200, body: chunks)
  end

  def stub_streamed_response(prompt, deltas, tool_call: false, skip_body_check: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    mock = WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")

    if !skip_body_check
      mock = mock.with(body: request_body(prompt, stream: true, tool_call: tool_call))
    end

    mock.to_return(status: 200, body: chunks)

    yield if block_given?
  end

  def tool_deltas
    [
      { id: tool_id, function: {} },
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { arguments: "" } },
      { id: tool_id, function: { arguments: "{" } },
      { id: tool_id, function: { arguments: " \"location\": \"Sydney\"" } },
      { id: tool_id, function: { arguments: " ,\"unit\": \"c\" }" } },
    ]
  end

  def tool_response
    {
      id: tool_id,
      function: {
        name: "get_weather",
        arguments: { location: "Sydney", unit: "c" }.to_json,
      },
    }
  end

  def tool_id
    "tool_0"
  end

  def tool_payload
    {
      type: "function",
      function: {
        name: "get_weather",
        description: "Get the weather in a city",
        parameters: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "the city name",
            },
            unit: {
              type: "string",
              description: "the unit of measurement celcius c or fahrenheit f",
              enum: %w[c f],
            },
          },
          required: %w[location unit],
        },
      },
    }
  end

  def request_body(prompt, stream: false, tool_call: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        if stream
          b[:stream] = true
          b[:stream_options] = { include_usage: true }
        end
        b[:tools] = [tool_payload] if tool_call
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model) { Fabricate(:llm_model) }

  let(:echo_tool) do
    {
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    }
  end

  let(:tools) { [echo_tool] }

  let(:open_ai_mock) { OpenAiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::ChatGpt, user)
  end

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  before { enable_current_plugin }

  describe "max tokens for reasoning models" do
    it "uses max_completion_tokens for reasoning models" do
      model.update!(name: "o3-mini", max_output_tokens: 999)
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, content: "hello"],
        )

      response_text = <<~RESPONSE
        data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model":"o3-mini-2025-01-31","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[{"index":0,"delta":{"role":"assistant","content":"","refusal":null},"finish_reason":null}],"usage":null}

        data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model":"o3-mini-2025-01-31","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[{"index":0,"delta":{"content":"hello"},"finish_reason":null}],"usage":null}

        data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model":"o3-mini-2025-01-31","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":null}

        data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model":"o3-mini-2025-01-31","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[],"usage":{"prompt_tokens":22,"completion_tokens":203,"total_tokens":225,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0},"completion_tokens_details":{"reasoning_tokens":192,"audio_tokens":0,"accepted_prediction_tokens":0,"rejected_prediction_tokens":0}}}

        data: [DONE]
      RESPONSE

      body_parsed = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body: ->(body) { body_parsed = JSON.parse(body) },
      ).to_return(body: response_text)
      result = +""
      llm.generate(prompt, user: user, max_tokens: 1000) { |chunk| result << chunk }

      expect(result).to eq("hello")
      expect(body_parsed["max_completion_tokens"]).to eq(999)

      llm.generate(prompt, user: user, max_tokens: 100) { |chunk| result << chunk }
      expect(body_parsed["max_completion_tokens"]).to eq(100)

      llm.generate(prompt, user: user) { |chunk| result << chunk }
      expect(body_parsed["max_completion_tokens"]).to eq(999)
    end
  end

  describe "repeat calls" do
    it "can properly reset context" do
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: tools,
        )

      response = {
        id: "chatcmpl-9JxkAzzaeO4DSV3omWvok9TKhCjBH",
        object: "chat.completion",
        created: 1_714_544_914,
        model: "gpt-4-turbo-2024-04-09",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_I8LKnoijVuhKOM85nnEQgWwd",
                  type: "function",
                  function: {
                    name: "echo",
                    arguments: "{\"text\":\"hello\"}",
                  },
                },
              ],
            },
            logprobs: nil,
            finish_reason: "tool_calls",
          },
        ],
        usage: {
          prompt_tokens: 55,
          completion_tokens: 13,
          total_tokens: 68,
        },
        system_fingerprint: "fp_ea6eb70039",
      }.to_json

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(body: response)

      result = llm.generate(prompt, user: user)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_I8LKnoijVuhKOM85nnEQgWwd",
          name: "echo",
          parameters: {
            text: "hello",
          },
        )

      expect(result).to eq(tool_call)

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        body: { choices: [message: { content: "OK" }] }.to_json,
      )

      result = llm.generate(prompt, user: user)

      expect(result).to eq("OK")
    end
  end

  describe "max tokens remapping" do
    it "remaps max_tokens to max_completion_tokens for reasoning models" do
      model.update!(name: "o3-mini")
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      body_parsed = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body: ->(body) { body_parsed = JSON.parse(body) },
      ).to_return(status: 200, body: { choices: [{ message: { content: "hello" } }] }.to_json)

      llm.generate("test", user: user, max_tokens: 1000)

      expect(body_parsed["max_completion_tokens"]).to eq(1000)
      expect(body_parsed["max_tokens"]).to be_nil
    end
  end

  describe "forced tool use" do
    it "can properly force tool use" do
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: tools,
          tool_choice: "echo",
        )

      response = {
        id: "chatcmpl-9JxkAzzaeO4DSV3omWvok9TKhCjBH",
        object: "chat.completion",
        created: 1_714_544_914,
        model: "gpt-4-turbo-2024-04-09",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_I8LKnoijVuhKOM85nnEQgWwd",
                  type: "function",
                  function: {
                    name: "echo",
                    arguments: "{\"text\":\"h<e>llo\"}",
                  },
                },
              ],
            },
            logprobs: nil,
            finish_reason: "tool_calls",
          },
        ],
        usage: {
          prompt_tokens: 55,
          completion_tokens: 13,
          total_tokens: 68,
        },
        system_fingerprint: "fp_ea6eb70039",
      }.to_json

      body_json = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body: proc { |body| body_json = JSON.parse(body, symbolize_names: true) },
      ).to_return(body: response)

      result = llm.generate(prompt, user: user, max_tokens: 1000)

      expect(body_json[:tool_choice]).to eq({ type: "function", function: { name: "echo" } })
      # we expect this not to be remapped on older non reasoning models
      expect(body_json[:max_tokens]).to eq(1000)

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(55)
      expect(log.response_tokens).to eq(13)
      expect(log.duration_msecs).not_to be_nil

      expected =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_I8LKnoijVuhKOM85nnEQgWwd",
          name: "echo",
          parameters: {
            text: "h<e>llo",
          },
        )

      expect(result).to eq(expected)

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        body: { choices: [message: { content: "OK" }] }.to_json,
      )

      result = llm.generate(prompt, user: user)

      expect(result).to eq("OK")
    end
  end

  describe "structured outputs" do
    it "falls back to best-effort parsing on broken JSON responses" do
      prompt = compliance.generic_prompt
      deltas = ["```json\n{ message: 'hel", "lo' }"]

      model_params = {
        response_format: {
          json_schema: {
            schema: {
              properties: {
                message: {
                  type: "string",
                },
              },
            },
          },
        },
      }

      read_properties = []
      open_ai_mock.with_chunk_array_support do
        # skip body check cause of response format
        open_ai_mock.stub_streamed_response(prompt, deltas, skip_body_check: true)

        dialect = compliance.dialect(prompt: prompt)

        endpoint.perform_completion!(dialect, user, model_params) do |partial|
          read_properties << partial.read_buffered_property(:message)
        end
      end

      expect(read_properties.join).to eq("hello")
    end
  end

  describe "disabled tool use" do
    it "can properly disable tool use with :none" do
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "don't use any tools please"],
          tools: tools,
          tool_choice: :none,
        )

      response = {
        id: "chatcmpl-9JxkAzzaeO4DSV3omWvok9TKhCjBH",
        object: "chat.completion",
        created: 1_714_544_914,
        model: "gpt-4-turbo-2024-04-09",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: "I won't use any tools. Here's a direct response instead.",
            },
            logprobs: nil,
            finish_reason: "stop",
          },
        ],
        usage: {
          prompt_tokens: 55,
          completion_tokens: 13,
          total_tokens: 68,
        },
        system_fingerprint: "fp_ea6eb70039",
      }.to_json

      body_json = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body: proc { |body| body_json = JSON.parse(body, symbolize_names: true) },
      ).to_return(body: response)

      result = llm.generate(prompt, user: user)

      # Verify that tool_choice is set to "none" in the request
      expect(body_json[:tool_choice]).to eq("none")
      expect(result).to eq("I won't use any tools. Here's a direct response instead.")
    end
  end

  describe "parameter disabling" do
    it "excludes disabled parameters from the request" do
      model.update!(provider_params: { disable_top_p: true, disable_temperature: true })

      parsed_body = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(
        status: 200,
        body: { choices: [{ message: { content: "test response" } }] }.to_json,
      )

      dialect = compliance.dialect(prompt: compliance.generic_prompt)

      # Request with parameters that should be ignored
      endpoint.perform_completion!(dialect, user, { top_p: 0.9, temperature: 0.8, max_tokens: 100 })

      # Verify disabled parameters aren't included
      expect(parsed_body).not_to have_key(:top_p)
      expect(parsed_body).not_to have_key(:temperature)

      # Verify other parameters still work
      expect(parsed_body).to have_key(:max_tokens)
      expect(parsed_body[:max_tokens]).to eq(100)
    end
  end

  describe "image support" do
    it "can handle images" do
      model = Fabricate(:llm_model, vision_enabled: true)
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are image bot",
          messages: [type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }]],
        )

      encoded = prompt.encoded_uploads(prompt.messages.last)

      parsed_body = nil

      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: { choices: [message: { content: "nice pic" }] }.to_json)

      completion = llm.generate(prompt, user: user)

      expect(completion).to eq("nice pic")
      expected_body = {
        model: "gpt-4-turbo",
        messages: [
          { role: "system", content: "You are image bot" },
          {
            role: "user",
            content: [
              { type: "text", text: "hello" },
              {
                type: "image_url",
                image_url: {
                  url: "data:#{encoded[0][:mime_type]};base64,#{encoded[0][:base64]}",
                },
              },
            ],
            name: "user1",
          },
        ],
      }
      expect(parsed_body).to eq(expected_body)
    end
  end

  describe "#perform_completion!" do
    context "when using XML tool calls format" do
      let(:xml_tool_call_response) { <<~XML }
        <function_calls>
        <invoke>
        <tool_name>get_weather</tool_name>
        <parameters>
        <location>Sydney</location>
        <unit>c</unit>
        <is_it_hot>true</is_it_hot>
        </parameters>
        </invoke>
        </function_calls>
      XML

      let(:weather_tool) do
        {
          name: "get_weather",
          description: "get weather",
          parameters: [
            { name: "location", type: "string", description: "location", required: true },
            { name: "unit", type: "string", description: "unit", required: true, enum: %w[c f] },
            { name: "is_it_hot", type: "boolean", description: "is it hot" },
          ],
        }
      end

      it "parses XML tool calls" do
        response = {
          id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
          object: "chat.completion",
          created: 1_678_464_820,
          model: "gpt-3.5-turbo-0301",
          usage: {
            prompt_tokens: 8,
            completion_tokens: 13,
            total_tokens: 499,
          },
          choices: [
            {
              message: {
                role: "assistant",
                content: xml_tool_call_response,
              },
              finish_reason: "stop",
              index: 0,
            },
          ],
        }.to_json

        endpoint.llm_model.update!(provider_params: { disable_native_tools: true })
        body = nil
        open_ai_mock.stub_raw(response, body_blk: proc { |inner_body| body = inner_body })

        dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: [weather_tool]))
        tool_call = endpoint.perform_completion!(dialect, user)

        body_parsed = JSON.parse(body, symbolize_names: true)
        expect(body_parsed[:tools]).to eq(nil)

        expect(body_parsed[:messages][0][:content]).to include("<function_calls>")

        expect(tool_call.name).to eq("get_weather")
        expect(tool_call.parameters).to eq({ location: "Sydney", unit: "c", is_it_hot: true })
      end
    end

    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(open_ai_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(open_ai_mock)
        end
      end
    end

    it "falls back to non-streaming mode when streaming is disabled" do
      model.update!(provider_params: { disable_streaming: true })

      response = {
        id: "chatcmpl-123",
        object: "chat.completion",
        created: 1_677_652_288,
        choices: [
          {
            message: {
              role: "assistant",
              content: "Hello there",
            },
            index: 0,
            finish_reason: "stop",
          },
        ],
      }

      parsed_body = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: response.to_json)

      chunks = []
      dialect = compliance.dialect(prompt: compliance.generic_prompt)
      endpoint.perform_completion!(dialect, user) { |chunk| chunks << chunk }

      expect(parsed_body).not_to have_key(:stream)

      expect(chunks).to eq(["Hello there"])
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(open_ai_mock)
        end

        it "will automatically recover from a bad payload" do
          called = false

          # this should not happen, but lets ensure nothing bad happens
          # the row with test1 is invalid json
          raw_data = <<~TEXT.strip
            d|a|t|a|:| |{|"choices":[{"delta":{"content":"test,"}}]}

            data: {"choices":[{"delta":{"content":"test|1| |,"}}]

            data: {"choices":[{"delta":|{"content":"test2 ,"}}]}

            data: {"choices":[{"delta":{"content":"test3,"}}]|}

            data: {"choices":[{|"|d|elta":{"content":"test4"}}]|}

            data: [D|ONE]
          TEXT

          chunks = raw_data.split("|")

          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)

            partials = []

            endpoint.perform_completion!(compliance.dialect, user) { |partial| partials << partial }

            called = true
            expect(partials.join).to eq("test,test2 ,test3,test4")
          end
          expect(called).to be(true)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.streaming_mode_tools(open_ai_mock)
        end

        it "properly handles multiple tool calls" do
          raw_data = <<~TEXT.strip
              data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"role":"assistant","content":null},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_3Gyr3HylFJwfrtKrL6NaIit1","type":"function","function":{"name":"search","arguments":""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"se"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"arch_"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"query\\""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":": \\"D"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"iscou"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"rse AI"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":" bot"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"}"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"call_H7YkbgYurHpyJqzwUN4bghwN","type":"function","function":{"name":"search","arguments":""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"{\\"qu"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"ery\\":"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":" \\"Disc"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"ours"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"e AI "}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"bot2\\"}"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{},"logprobs":null,"finish_reason":"tool_calls"}]}

  data: [DONE]
TEXT

          open_ai_mock.stub_raw(raw_data)
          response = []

          dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))

          endpoint.perform_completion!(dialect, user) { |partial| response << partial }

          tool_calls = [
            DiscourseAi::Completions::ToolCall.new(
              name: "search",
              id: "call_3Gyr3HylFJwfrtKrL6NaIit1",
              parameters: {
                search_query: "Discourse AI bot",
              },
            ),
            DiscourseAi::Completions::ToolCall.new(
              name: "search",
              id: "call_H7YkbgYurHpyJqzwUN4bghwN",
              parameters: {
                query: "Discourse AI bot2",
              },
            ),
          ]

          expect(response).to eq(tool_calls)
        end

        it "properly handles newlines" do
          response = <<~TEXT.strip
            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":":\\n\\n"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"```"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"ruby"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"\\n"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"def"},"logprobs":null,"finish_reason":null}],"usage":null}
         TEXT

          open_ai_mock.stub_raw(response)
          partials = []

          dialect = compliance.dialect(prompt: compliance.generic_prompt)
          endpoint.perform_completion!(dialect, user) { |partial| partials << partial }

          expect(partials).to eq([":\n\n", "```", "ruby", "\n", "def"])
        end

        it "uses proper token accounting" do
          response = <<~TEXT.strip
            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{"role":"assistant","content":""},"logprobs":null,"finish_reason":null}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{"content":"Hello"},"logprobs":null,"finish_reason":null}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{},"logprobs":null,"finish_reason":"stop"}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[],"usage":{"prompt_tokens":20,"completion_tokens":9,"total_tokens":29}}|

            data: [DONE]
          TEXT

          chunks = response.split("|")
          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)
            partials = []

            dialect = compliance.dialect(prompt: compliance.generic_prompt)
            endpoint.perform_completion!(dialect, user) { |partial| partials << partial }

            expect(partials).to eq(["Hello"])

            log = AiApiAuditLog.order("id desc").first

            expect(log.request_tokens).to eq(20)
            expect(log.response_tokens).to eq(9)
          end
        end

        it "properly handles multiple params in partial tool calls" do
          # this is not working and it is driving me nuts so I will use a sledghammer
          # text = plugin_file_from_fixtures("openai_artifact_call.txt", "bot")

          path = File.join(__dir__, "../../../fixtures/bot", "openai_artifact_call.txt")
          text = File.read(path)

          partials = []
          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(text.scan(/.*\n/))

            dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))
            endpoint.perform_completion!(dialect, user, partial_tool_calls: true) do |partial|
              partials << partial.dup
            end
          end

          expect(partials.compact.length).to eq(128)

          params =
            partials
              .map { |p| p.parameters if p.is_a?(DiscourseAi::Completions::ToolCall) && p.partial? }
              .compact

          lengths = {}
          params.each do |p|
            p.each do |k, v|
              if lengths[k] && lengths[k] > v.length
                expect(lengths[k]).to be > v.length
              else
                lengths[k] = v.length
              end
            end
          end

          audit_log = AiApiAuditLog.order("id desc").first
          expect(audit_log.cached_tokens).to eq(33)
        end

        it "properly handles spaces in tools payload and partial tool calls" do
          raw_data = <<~TEXT.strip
            data: {"choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"func_id","type":"function","function":{"name":"go|ogle","arg|uments":""}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "{\\""}}]}}]}

            data: {"ch|oices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "query"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "\\":\\""}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "Ad"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "a|b"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "as"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": |"| "}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "9"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "."}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"argume|nts": "1"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "\\"}"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": []}}]}

            data: [D|ONE]
          TEXT

          chunks = raw_data.split("|")

          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)
            partials = []

            dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))
            endpoint.perform_completion!(dialect, user, partial_tool_calls: true) do |partial|
              partials << partial.dup
            end

            tool_call =
              DiscourseAi::Completions::ToolCall.new(
                id: "func_id",
                name: "google",
                parameters: {
                  query: "Adabas 9.1",
                },
              )

            expect(partials.last).to eq(tool_call)

            progress = partials.map { |p| p.parameters[:query] }
            expect(progress).to eq(["Ad", "Adabas", "Adabas 9.", "Adabas 9.1"])
          end
        end
      end
    end
  end
end
