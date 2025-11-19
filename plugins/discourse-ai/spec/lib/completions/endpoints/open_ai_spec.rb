# frozen_string_literal: true

require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  fab!(:user)
  fab!(:a_model, :llm_model)

  before { enable_current_plugin }

  def generic_prompt(tools: [], tool_choice: nil)
    DiscourseAi::Completions::Prompt.new(
      "You write words",
      messages: [{ type: :user, content: "write 3 words" }],
      tools: tools,
      tool_choice: tool_choice,
    )
  end

  def with_scripted_responses(responses, llm: a_model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm,
      transport: :scripted_http,
      &block
    )
  end

  fab!(:user)

  let(:llm) { DiscourseAi::Completions::Llm.proxy(a_model) }
  let(:endpoint) { described_class.new(a_model) }

  let(:weather_tool_definition) do
    DiscourseAi::Completions::ToolDefinition.from_hash(
      name: "lookup_weather",
      description: "Fetch weather details",
      parameters: [
        { name: "location", type: "string", description: "City", required: true },
        { name: "units", type: "string", description: "Units (c/f)", required: true },
      ],
    )
  end

  let(:calendar_tool_definition) do
    DiscourseAi::Completions::ToolDefinition.from_hash(
      name: "create_calendar_event",
      description: "Create a calendar entry",
      parameters: [
        { name: "title", type: "string", description: "Event title", required: true },
        { name: "time", type: "string", description: "Time slot", required: true },
      ],
    )
  end

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  describe "max tokens remapping" do
    it "maps max_tokens to max_completion_tokens for reasoning endpoints" do
      a_model.update!(name: "o3-mini", max_output_tokens: 999)

      prompt = generic_prompt

      with_scripted_responses(%w[hello hello hello]) do |scripted_http|
        buffer = +""
        llm.generate(prompt, user: user, max_tokens: 1000) { |chunk| buffer << chunk }
        expect(buffer).to eq("hello")

        expect(scripted_http.last_request["max_completion_tokens"]).to eq(999)

        llm.generate(prompt, user: user, max_tokens: 100) { |chunk| buffer << chunk }
        expect(scripted_http.last_request["max_completion_tokens"]).to eq(100)

        llm.generate(prompt, user: user) { |chunk| buffer << chunk }
        expect(scripted_http.last_request["max_completion_tokens"]).to eq(999)
      end
    end

    it "keeps max_tokens for non-reasoning models" do
      with_scripted_responses(["hello"]) do |scripted_http|
        llm.generate("test", user: user, max_tokens: 321)
        body = scripted_http.last_request
        expect(body["max_tokens"]).to eq(321)
        expect(body["max_completion_tokens"]).to be_nil
      end
    end
  end

  describe "forced tool use" do
    it "respects tool_choice and logs usage" do
      tools = [
        DiscourseAi::Completions::ToolDefinition.from_hash(
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        ),
      ]

      prompt = generic_prompt(tools: tools, tool_choice: "echo")

      expected_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_123",
          name: "echo",
          parameters: {
            text: "h<e>llo",
          },
        )

      responses = [
        { tool_calls: [{ id: "call_123", name: "echo", arguments: { text: "h<e>llo" } }] },
        "OK",
      ]

      with_scripted_responses(responses) do |scripted_http|
        tool_call = nil
        llm.generate(prompt, user: user, max_tokens: 1000) { |chunk| tool_call = chunk }

        expect(tool_call.name).to eq("echo")

        body = scripted_http.last_request
        expect(body["tool_choice"]).to eq(
          { "type" => "function", "function" => { "name" => "echo" } },
        )
        expect(body["max_tokens"]).to eq(1000)

        log = AiApiAuditLog.order(:id).last
        expect(log).not_to be_nil
        expect(log.request_tokens).to be > 0
        expect(log.response_tokens).to be > 0

        expect(tool_call).to eq(expected_call)

        expect(llm.generate(prompt, user: user)).to eq("OK")
      end
    end
  end

  describe "structured outputs" do
    it "falls back to best-effort parsing on broken JSON responses" do
      response_format = { json_schema: { schema: { properties: { message: { type: "string" } } } } }

      chunks = []

      with_scripted_responses(["```json\n{ message: 'hello' }"]) do
        llm.generate(generic_prompt, user: user, response_format: response_format) do |partial|
          if partial.respond_to?(:read_buffered_property)
            chunks << partial.read_buffered_property(:message)
          end
        end
      end

      expect(chunks.join).to eq("hello")
    end
  end

  describe "disabled tool use" do
    it "sends tool_choice none when requested" do
      prompt = generic_prompt(tools: [weather_tool_definition], tool_choice: :none)

      with_scripted_responses(["hi there"]) do |scripted_http|
        expect(llm.generate(prompt, user: user)).to eq("hi there")
        expect(scripted_http.last_request["tool_choice"]).to eq("none")
      end
    end
  end

  describe "streaming plain text" do
    it "streams text chunks and returns the final message" do
      chunks = []

      with_scripted_responses(["Hello world!"]) do
        result =
          llm.generate(generic_prompt, user: user) do |partial|
            chunks << partial if partial.is_a?(String)
          end

        expect(result).to eq("Hello world!")
        expect(chunks.size).to be > 1 # Testing response came in chunks.
        expect(chunks.join).to eq("Hello world!")
      end
    end

    it "preserves multiline formatting when streaming responses" do
      expected = "Here is some code:\n\n```ruby\nputs 'hi'\n```"
      fragments = []

      with_scripted_responses([expected]) do
        llm.generate(generic_prompt, user: user) do |partial|
          fragments << partial if partial.is_a?(String)
        end
      end

      expect(fragments).not_to be_empty
      expect(fragments.join).to eq(expected)
    end
  end

  describe "streaming resilience" do
    it "recovers from malformed streamed payloads" do
      raw_data = <<~TEXT.strip
        d|a|t|a|:| |{|"choices":[{"delta":{"content":"test,"}}]}

        data: {"choices":[{"delta":{"content":"test|1| |,"}}]

        data: {"choices":[{"delta":|{"content":"test2 ,"}}]}

        data: {"choices":[{"delta":{"content":"test3,"}}]|}

        data: {"choices":[{|"|d|elta":{"content":"test4"}}]|}

        data: [D|ONE]
      TEXT

      chunks = raw_data.split("|")
      buffered = []

      with_scripted_responses([{ raw_stream: chunks }]) do
        llm.generate(generic_prompt, user: user) do |partial|
          buffered << partial if partial.is_a?(String)
        end
      end

      expect(buffered.join).to eq("test,test2 ,test3,test4")
    end
  end

  describe "parameter disabling" do
    it "omits disabled parameters from payload" do
      a_model.update!(provider_params: { disable_top_p: true, disable_temperature: true })

      with_scripted_responses(["test response"]) do |scripted_http|
        llm.generate(generic_prompt, user: user, top_p: 0.9, temperature: 0.8, max_tokens: 100)

        body = scripted_http.last_request
        expect(body).not_to have_key("top_p")
        expect(body).not_to have_key("temperature")
        expect(body["max_tokens"]).to eq(100)
      end
    end
  end

  describe "image support" do
    it "embeds uploads when vision is enabled" do
      vision_model = Fabricate(:llm_model, vision_enabled: true)

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are image bot",
          messages: [
            { type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }] },
          ],
        )

      encoded = prompt.encode_upload(upload100x100.id)

      with_scripted_responses(["nice pic"], llm: vision_model) do |scripted_http|
        vision_llm = DiscourseAi::Completions::Llm.proxy(vision_model)

        response = vision_llm.generate(prompt, user: user)
        expect(response).to eq("nice pic")

        body = scripted_http.last_request
        expect(body["messages"].last["content"]).to include(
          {
            "type" => "image_url",
            "image_url" => {
              "url" => "data:#{encoded[:mime_type]};base64,#{encoded[:base64]}",
            },
          },
        )
      end
    end
  end

  describe "streaming disabling" do
    it "falls back to non-streaming mode when streaming is disabled" do
      a_model.update!(provider_params: { disable_streaming: true })

      with_scripted_responses(["Hello there"]) do |scripted_http|
        chunks = []
        llm.generate(generic_prompt, user: user) { |partial| chunks << partial }

        expect(scripted_http.last_request).not_to have_key("stream")

        expect(chunks).to eq(["Hello there"])
      end
    end
  end

  describe "audit logging and streaming" do
    it "records audit log entries for non-streaming completions" do
      with_scripted_responses(["Serenity now"]) do |scripted_http|
        result = llm.generate(generic_prompt, user: user)
        expect(result).to eq("Serenity now")

        log = AiApiAuditLog.order(:id).last
        expect(log.provider_id).to eq(endpoint.provider_id)
        expect(log.user_id).to eq(user.id)
        expect(log.raw_request_payload).to be_present

        response_json = JSON.parse(log.raw_response_payload)
        expect(response_json.dig("choices", 0, "message", "content")).to eq("Serenity now")
        expect(response_json.dig("choices", 0, "finish_reason")).to eq("stop")

        expect(log.request_tokens).to be_positive
        expect(log.response_tokens).to eq(a_model.tokenizer_class.size("Serenity now"))

        request_body = scripted_http.last_request
        expect(request_body["stream"]).not_to eq(true)
      end
    end

    it "records audit log entries for streaming completions and honours cancellations" do
      cancel_manager = DiscourseAi::Completions::CancelManager.new
      fragments = []

      with_scripted_responses(["Stream the peaceful mountain air"]) do
        llm.generate(generic_prompt, user: user, cancel_manager: cancel_manager) do |partial|
          next if !partial.is_a?(String)
          fragments << partial
          cancel_manager.cancel! if fragments.join.split.length >= 3
        end
      end

      expect(cancel_manager.cancelled?).to eq(true)

      log = AiApiAuditLog.order(:id).last
      expect(log.raw_request_payload).to be_present
      expect(log.raw_response_payload).to include("chat.completion.chunk")
      expect(log.response_tokens).to eq(a_model.tokenizer_class.size(fragments.join))
    end
  end

  describe "performing a completion" do
    context "when native tools are disabled" do
      let(:xml_tool_call_response) { <<~XML }
        <function_calls>
        <invoke>
        <tool_name>get_weather</tool_name>
        <parameters>
        <location>Sydney</location>
        <units>c</units>
        </parameters>
        </invoke>
        </function_calls>
      XML

      it "parses XML tool calls" do
        a_model.update!(provider_params: { disable_native_tools: true })

        prompt = generic_prompt(tools: [weather_tool_definition])

        with_scripted_responses([xml_tool_call_response]) do |scripted_http|
          tool_call = llm.generate(prompt, user: user)

          body = scripted_http.last_request
          expect(body["tools"]).to be_nil
          expect(body["messages"].first["content"]).to include("<function_calls>")

          expect(tool_call).to be_a(DiscourseAi::Completions::ToolCall)
          expect(tool_call.name).to eq("get_weather")
          expect(tool_call.parameters).to eq({ location: "Sydney", units: "c" })
        end
      end
    end

    context "when tool calls are returned without streaming" do
      it "returns all tool calls" do
        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a planner bot",
            messages: [{ type: :user, content: "Get weather then schedule packing" }],
            tools: [weather_tool_definition, calendar_tool_definition],
          )

        response = {
          tool_calls: [
            {
              id: "call_weather",
              name: "lookup_weather",
              arguments: {
                location: "Paris",
                units: "c",
              },
            },
            {
              id: "call_calendar",
              name: "create_calendar_event",
              arguments: {
                title: "Pack bags",
                time: "18:00",
              },
            },
          ],
        }

        final = nil

        with_scripted_responses([response]) { final = llm.generate(prompt, user: user) }

        expect(final).to be_a(Array)
        expect(final.map(&:name)).to eq(%w[lookup_weather create_calendar_event])
        expect(final.first.parameters).to eq({ location: "Paris", units: "c" })
        expect(final.last.parameters).to eq({ title: "Pack bags", time: "18:00" })
      end
    end

    context "when streaming tool calls" do
      it "yields partial tool updates and final tool result" do
        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a bot",
            messages: [{ type: :user, content: "lookup weather" }],
            tools: [weather_tool_definition],
          )

        tool_response = {
          tool_calls: [
            {
              id: "call_weather",
              name: "lookup_weather",
              arguments: {
                location: "SFO",
                units: "f",
              },
            },
          ],
        }

        partials = []

        with_scripted_responses([tool_response]) do
          llm.generate(prompt, user: user, partial_tool_calls: true) do |partial|
            partials << partial.dup if partial.is_a?(DiscourseAi::Completions::ToolCall)
          end
        end

        final = partials.find { |p| !p.partial }

        expect(final).to be_a(DiscourseAi::Completions::ToolCall)
        expect(final.parameters).to eq({ location: "SFO", units: "f" })
        expect(partials.any?(&:partial?)).to eq(true)
        expect(partials.last.partial?).to eq(false)
      end

      it "records cached token usage when streaming tool calls" do
        usage_payload = {
          prompt_tokens: 24,
          completion_tokens: 16,
          total_tokens: 40,
          prompt_tokens_details: {
            cached_tokens: 33,
          },
        }

        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a planner bot",
            messages: [{ type: :user, content: "Get weather then schedule packing" }],
            tools: [weather_tool_definition],
          )

        response = {
          tool_calls: [
            {
              id: "call_weather",
              name: "lookup_weather",
              arguments: {
                location: "Paris",
                units: "c",
              },
            },
          ],
          usage: usage_payload,
        }

        expect do
          with_scripted_responses([response]) do
            llm.generate(prompt, user: user, partial_tool_calls: true) { |_partial| nil }
          end
        end.to change { AiApiAuditLog.count }.by(1)

        log = AiApiAuditLog.order(:id).last
        expect(log.cached_tokens).to eq(usage_payload.dig(:prompt_tokens_details, :cached_tokens))
        expect(log.response_tokens).to eq(usage_payload[:completion_tokens])
      end
    end

    context "when streaming multiple tool calls" do
      it "yields partial updates for each tool and returns them all" do
        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a planner bot",
            messages: [{ type: :user, content: "Get weather then schedule packing" }],
            tools: [weather_tool_definition, calendar_tool_definition],
          )

        tool_stream = {
          tool_calls: [
            {
              id: "call_weather",
              name: "lookup_weather",
              arguments: {
                location: "Paris",
                units: "c",
              },
            },
            {
              id: "call_calendar",
              name: "create_calendar_event",
              arguments: {
                title: "Pack bags",
                time: "18:00",
              },
            },
          ],
        }

        partials = []

        with_scripted_responses([tool_stream]) do
          llm.generate(prompt, user: user, partial_tool_calls: true) do |partial|
            partials << partial.dup if partial.is_a?(DiscourseAi::Completions::ToolCall)
          end
        end

        final = partials.select { |p| !p.partial }

        expect(final).to be_a(Array)
        expect(final.map(&:name)).to eq(%w[lookup_weather create_calendar_event])
        expect(final.first.parameters).to eq({ location: "Paris", units: "c" })
        expect(final.last.parameters).to eq({ title: "Pack bags", time: "18:00" })
        expect(partials.any?(&:partial?)).to eq(true)
        expect(partials.map(&:name).uniq).to include("lookup_weather", "create_calendar_event")
        expect(partials.last.partial?).to eq(false)
      end
    end

    context "when making repeat calls" do
      it "resets context between calls" do
        tools = [
          DiscourseAi::Completions::ToolDefinition.from_hash(
            name: "echo",
            description: "repeat text",
            parameters: [
              { name: "text", type: "string", description: "text to echo", required: true },
            ],
          ),
        ]

        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a bot",
            messages: [{ type: :user, id: "user1", content: "echo hello" }],
            tools: tools,
          )

        responses = [
          { tool_calls: [{ id: "call_echo", name: "echo", arguments: { text: "hello" } }] },
          "OK",
        ]

        results = []

        with_scripted_responses(responses) do
          results << llm.generate(prompt, user: user)
          results << llm.generate(prompt, user: user)
        end

        expect(results.first).to be_a(DiscourseAi::Completions::ToolCall)
        expect(results.first.parameters).to eq({ text: "hello" })
        expect(results.last).to eq("OK")
      end
    end
  end

  describe "reasoning effort payload format" do
    it "uses reasoning object format for responses API" do
      a_model.update!(provider_params: { enable_responses_api: true, reasoning_effort: "minimal" })

      with_scripted_responses(["test"]) do |scripted_http|
        llm.generate(generic_prompt, user: user)

        body = scripted_http.last_request
        expect(body["reasoning"]).to eq({ "effort" => "minimal" })
        expect(body).not_to have_key("reasoning_effort")
      end
    end

    it "uses reasoning_effort field for standard API and sets developer role" do
      a_model.update!(name: "gpt-5", provider_params: { reasoning_effort: "low" })

      with_scripted_responses(["hello"]) do |scripted_http|
        llm.generate(generic_prompt, user: user, max_tokens: 321)

        body = scripted_http.last_request

        expect(body["model"]).to eq("gpt-5")
        expect(body["max_completion_tokens"]).to eq(321)
        expect(body["reasoning_effort"]).to eq("low")
        expect(body).not_to have_key("reasoning")
        expect(body["messages"].first["role"]).to eq("developer")
      end
    end

    it "omits reasoning parameters when not configured" do
      with_scripted_responses(["test"]) do |scripted_http|
        llm.generate(generic_prompt, user: user)

        body = scripted_http.last_request
        expect(body).not_to have_key("reasoning")
        expect(body).not_to have_key("reasoning_effort")
      end
    end
  end
end
