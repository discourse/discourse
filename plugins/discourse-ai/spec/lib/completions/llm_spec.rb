# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Llm do
  describe "upload skips" do
    fab!(:vision_model) { Fabricate(:anthropic_model, vision_enabled: true) }

    it "hands the execution context's collector to the prompt it is about to translate" do
      upload = Fabricate(:upload, original_filename: "avatar.jxl", extension: "jxl")
      execution_context = DiscourseAi::Completions::ExecutionContext.new
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "system",
          messages: [{ type: :user, content: ["look", { upload_id: upload.id }] }],
        )

      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        body: {
          id: "msg_1",
          type: "message",
          role: "assistant",
          content: [{ type: "text", text: "done" }],
          model: "claude-3-opus",
          usage: {
            input_tokens: 1,
            output_tokens: 1,
          },
        }.to_json,
      )

      vision_model.to_llm.generate(
        prompt,
        user: Discourse.system_user,
        execution_context: execution_context,
      )

      expect(execution_context.upload_skips.map { |skip| skip[:upload_id] }).to eq([upload.id])
    end
  end

  fab!(:user)
  fab!(:model, :llm_model)

  let(:llm) { described_class.proxy(model) }

  before { enable_current_plugin }

  describe "turn work settlement" do
    it "blocks unadmitted helper generations when work or the shared completion bound is exhausted" do
      request = stub_response
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 4000),
        )
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: execution,
          root_token_budget: 4000,
        )
      expect { llm.generate("Helper", user: user, execution_context: execution) }.to raise_error(
        DiscourseAi::Completions::ContextPreparation::Error,
        /turn_budget_exhausted/,
      )
      execution.work_budget = DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000)
      99.times { state.reserve_completion }
      expect { llm.generate("Helper", user: user, execution_context: execution) }.to raise_error(
        DiscourseAi::Completions::ContextPreparation::Error,
        /completion_limit/,
      )
      expect(request).not_to have_been_requested
      expect(execution.work_budget.remaining).to eq(4000)
    end

    it "counts normalized output including invisible reasoning once, independent of input and cache" do
      body = success_body(prompt_tokens: 100_000, completion_tokens: 37)
      body[:usage][:prompt_tokens_details] = { cached_tokens: 90_000 }
      body[:usage][:completion_tokens_details] = { reasoning_tokens: 30 }
      body[:choices][0][:message][:tool_calls] = [
        {
          id: "call",
          type: "function",
          function: {
            name: "read",
            arguments: '{"query":"evidence"}',
          },
        },
      ]
      cold = body.deep_dup
      cold[:usage][:prompt_tokens_details] = { cached_tokens: 0 }
      stub_request(:post, model.url).to_return({ body: body.to_json }, { body: cold.to_json })
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
        )
      2.times do
        llm.generate(
          "Current input is free",
          user: user,
          execution_context: execution,
          output_thinking: true,
        )
      end
      expect(execution.work_budget.used).to eq(74)
      expect(execution.token_usage_tracker.request).to eq(119_000)
      expect(execution.token_usage_tracker.response).to eq(74)
    end

    it "bills maintenance but leaves work unchanged" do
      stub_response
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 123),
        )
      llm.generate(
        "Summarize history",
        user: user,
        feature_name: "context_compression",
        execution_context: execution,
      )
      expect(execution.work_budget.used).to eq(123)
      expect(execution.token_usage_tracker.total).to eq(15)
      expect(execution.token_usage_tracker.preparation_tokens).to eq(15)
    end

    it "estimates decoded output without usage rather than counting provider-envelope bytes" do
      body = success_body(content: "Short answer")
      body.delete(:usage)
      body[:id] = "envelope" * 100
      stub_response(body: body)
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
        )
      llm.generate("History " * 50, user: user, execution_context: execution)
      expect(execution.work_budget.used).to eq(llm.tokenizer.size("Short answer"))
    end

    it "settles cancelled Base output and keeps its actual usage audit" do
      stub_response(body: streaming_body(content: "Partial answer"))
      cancel = DiscourseAi::Completions::CancelManager.new
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
        )
      llm.generate("Input", user: user, execution_context: execution, cancel_manager: cancel) do
        cancel.cancel!
      end
      expect(execution.work_budget.used).to eq(llm.tokenizer.size("Partial answer"))
      expect(execution.token_usage_tracker.response).to be > 0
      expect(AiApiAuditLog.last.raw_response_payload).to include("Partial answer")
    end

    it "settles already emitted generation when a streaming consumer fails" do
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(["Partial output"]) do
        expect {
          llm.generate("Input", user: user, execution_context: execution) do
            raise "consumer failed"
          end
        }.to raise_error(RuntimeError, "consumer failed")
      end
      expect(execution.work_budget.used).to eq(llm.tokenizer.size("P"))
    end
  end

  def stub_response(status: 200, body: success_body)
    WebMock.stub_request(:post, model.url).to_return(
      status:,
      body: body.is_a?(Hash) ? body.to_json : body,
    )
  end

  def success_body(content: "test", prompt_tokens: 10, completion_tokens: 5)
    {
      model: model.name,
      usage: {
        prompt_tokens:,
        completion_tokens:,
        total_tokens: prompt_tokens + completion_tokens,
      },
      choices: [{ message: { role: "assistant", content: }, finish_reason: "stop" }],
    }
  end

  def streaming_body(content: "Hello")
    <<~SSE
      data: {"id":"1","object":"chat.completion.chunk","choices":[{"delta":{"content":#{content.to_json}}}]}

      data: [DONE]
    SSE
  end

  describe ".text_from_response" do
    it "returns only text from heterogeneous completion responses" do
      thinking = DiscourseAi::Completions::Thinking.new(message: "Private reasoning")
      tool_call =
        DiscourseAi::Completions::ToolCall.new(id: "tool-1", name: "search", parameters: {})
      structured_output =
        DiscourseAi::Completions::StructuredOutput.new(message: { type: "string" })
      structured_output << '{"message":"Visible response"}'
      structured_output.finish

      expect(described_class.text_from_response(["Visible", thinking, " response"])).to eq(
        "Visible response",
      )
      expect(described_class.text_from_response("Visible response")).to eq("Visible response")
      expect(described_class.text_from_response(structured_output)).to eq(
        '{"message":"Visible response"}',
      )
      expect(described_class.text_from_response(thinking)).to eq("")
      expect(described_class.text_from_response(tool_call)).to eq("")
      expect(described_class.text_from_response(nil)).to eq("")
    end
  end

  describe ".proxy" do
    it "raises for unknown model identifiers" do
      expect { described_class.proxy("unknown:v2") }.to raise_error(described_class::UNKNOWN_MODEL)
    end
  end

  describe "#prompt_capacity" do
    it "admits native PDFs on supported providers and reserves rendered pages plus extracted text" do
      pdf = file_from_fixtures("2-page.pdf", "rag", "plugins/discourse-ai/spec/fixtures")
      encoded = {
        kind: :document,
        filename: "2-page.pdf",
        mime_type: "application/pdf",
        base64: Base64.strict_encode64(File.binread(pdf.path)),
      }
      models = [
        Fabricate(:llm_model, allowed_attachment_types: ["pdf"]),
        Fabricate(:anthropic_model, allowed_attachment_types: ["pdf"]),
        Fabricate(:gemini_model, allowed_attachment_types: ["pdf"]),
      ]
      models.each do |supported_model|
        prompt =
          DiscourseAi::Completions::Prompt.new(
            "Instructions",
            messages: [
              { type: :user, content: ["Read this document", { encoded_upload: encoded }] },
            ],
          )
        measured_llm = supported_model.to_llm
        size, capacity, output = measured_llm.prompt_capacity(prompt)
        expect(size).to be >= 8192
        expect(size).to be < capacity
        expect(output).to be > 0
        expect(measured_llm.prompt_capacity(prompt)).to eq([size, capacity, output])
      end
    end

    it "rejects binary documents on a text-only document dialect without silently omitting them" do
      model = Fabricate(:bedrock_converse_model, allowed_attachment_types: ["pdf"])
      pdf = file_from_fixtures("2-page.pdf", "rag", "plugins/discourse-ai/spec/fixtures")
      encoded = {
        kind: :document,
        filename: "2-page.pdf",
        mime_type: "application/pdf",
        base64: Base64.strict_encode64(File.binread(pdf.path)),
      }
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Instructions",
          messages: [{ type: :user, content: ["Read this document", { encoded_upload: encoded }] }],
        )
      expect { model.to_llm.prompt_capacity(prompt) }.to raise_error(
        DiscourseAi::Completions::ContextPreparation::Error,
        /unsupported_document_provider/,
      )
    end

    it "counts ordinary data-prefixed text and data schema fields instead of treating them as binary" do
      model.update!(max_prompt_tokens: 16_000)
      text = "data:#{"Important request evidence " * 10_000}"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Instructions",
          messages: [{ type: :user, content: text }],
        )
      size, capacity = llm.prompt_capacity(prompt)
      expect(size).to be > capacity
      short_prompt =
        DiscourseAi::Completions::Prompt.new(
          "Instructions",
          messages: [{ type: :user, content: "Short request" }],
        )
      schema_size, schema_capacity =
        llm.prompt_capacity(short_prompt, response_format: { data: text })
      expect(schema_size).to be > schema_capacity
    end

    it "preserves a batch of small images without the old per-megapixel over-reservation" do
      model.update!(vision_enabled: true, max_prompt_tokens: 16_000)
      image = {
        encoded_upload: {
          kind: :image,
          mime_type: "image/png",
          base64:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wcAAgEB/awxUE0AAAAASUVORK5CYII=",
        },
      }
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Instructions",
          messages: [{ type: :user, content: ["Review these six images", *Array.new(6, image)] }],
        )
      size, capacity = llm.prompt_capacity(prompt)
      expect(size).to be < capacity
      expect(prompt.messages.last[:content].grep(Hash).length).to eq(6)
      original = llm.prompt_capacity(prompt)
      prompt.messages.last[:content].unshift("Additional evidence " * 1000)
      expect(llm.prompt_capacity(prompt).first).to be > original.first
    end
  end

  describe "#generate" do
    context "with different prompt formats" do
      before { stub_response(body: success_body(content: "world")) }

      it "accepts a simple string" do
        expect(llm.generate("hello", user:)).to eq("world")
      end

      it "accepts an array of messages" do
        messages = [{ type: :system, content: "bot" }, { type: :user, content: "hello" }]
        expect(llm.generate(messages, user:)).to eq("world")
      end
    end

    context "with streaming" do
      it "yields partials via block" do
        stub_response(body: streaming_body(content: "Hi"))

        result = +""
        llm.generate("hi", user:) { |partial| result << partial }
        expect(result).to eq("Hi")
      end

      it "replays non-streaming responses when streaming is disabled" do
        model.update!(provider_params: { "disable_streaming" => true })
        stub_response(body: success_body(content: "Hi"))

        partials = []
        result = llm.generate("hi", user:) { |partial| partials << partial }

        expect(result).to eq("Hi")
        expect(partials).to eq(["Hi"])
      end
    end

    context "with a fake model" do
      fab!(:fake_model)

      before do
        DiscourseAi::Completions::Endpoints::Fake.delays = []
        DiscourseAi::Completions::Endpoints::Fake.chunk_count = 10
      end

      it "generates and streams responses" do
        fake_llm = described_class.proxy(fake_model)
        prompt =
          DiscourseAi::Completions::Prompt.new("System", messages: [{ type: :user, content: "hi" }])

        expect(fake_llm.generate(prompt, user:)).to be_present

        partials = []
        response = fake_llm.generate(prompt, user:) { |p| partials << p }
        expect(partials.size).to eq(10)
        expect(partials.join).to eq(response)
      end
    end

    context "with structured output" do
      it "returns a structured output buffer" do
        stub_response(body: success_body(content: '{"message":"ok"}'))

        result =
          llm.generate(
            "hello",
            user:,
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
          )

        expect(result).to be_a(DiscourseAi::Completions::StructuredOutput)
        expect(result).to be_finished
        expect(result.to_s).to eq('{"message":"ok"}')
      end
    end

    context "when auditing" do
      it "logs topic_id, post_id, feature_name, and feature_context" do
        stub_response(body: success_body)

        llm.generate(
          DiscourseAi::Completions::Prompt.new(
            "sys",
            messages: [{ type: :user, content: "hi" }],
            topic_id: 123,
            post_id: 1,
          ),
          user:,
          feature_name: "triage",
          feature_context: {
            foo: "bar",
          },
        )

        expect(AiApiAuditLog.last).to have_attributes(
          topic_id: 123,
          post_id: 1,
          feature_name: "triage",
          feature_context: {
            "foo" => "bar",
          },
        )
      end

      it "records response status" do
        stub_response(status: 200)
        llm.generate("Hello", user:)
        expect(AiApiAuditLog.last.response_status).to eq(200)

        stub_response(status: 401, body: "error")
        expect { llm.generate("Hello", user:) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(AiApiAuditLog.last).to have_attributes(
          response_status: 401,
          response_tokens: 0,
          time_to_first_token_msecs: nil,
        )
      end

      it "records time to the complete response for non-streaming requests" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .stubs(:monotonic_milliseconds)
          .returns(1_000, 1_125)
        stub_response(body: success_body(content: "Hello"))

        expect(llm.generate("Hello", user:)).to eq("Hello")
        expect(AiApiAuditLog.last.time_to_first_token_msecs).to eq(125)
      end

      it "records time to the first emitted partial for streaming requests" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .stubs(:monotonic_milliseconds)
          .returns(1_000, 1_075)
        stub_response(body: streaming_body(content: "Hello"))

        response = +""
        llm.generate("Hello", user:) { |partial| response << partial }

        expect(response).to eq("Hello")
        expect(AiApiAuditLog.last.time_to_first_token_msecs).to eq(75)
      end

      it "creates usage stats" do
        stub_response(body: success_body(prompt_tokens: 20, completion_tokens: 10))

        expect { llm.generate("Hello", user:) }.to change { AiApiRequestStat.count }.by(1)

        expect(AiApiRequestStat.last).to have_attributes(
          llm_id: model.id,
          usage_count: 1,
          rolled_up: false,
        )
      end
    end

    context "with temperature and top_p" do
      fab!(:fake_model)

      before do
        DiscourseAi::Completions::Endpoints::Fake.delays = []
        DiscourseAi::Completions::Endpoints::Fake.last_call = nil
      end

      it "drops temperature and top_p when ai_llm_temperature_top_p_enabled is false" do
        SiteSetting.ai_llm_temperature_top_p_enabled = false
        fake_llm = described_class.proxy(fake_model)
        fake_llm.generate("hello", user:, temperature: 0.5, top_p: 0.9)

        last_call = DiscourseAi::Completions::Endpoints::Fake.last_call
        expect(last_call[:model_params]).not_to have_key(:temperature)
        expect(last_call[:model_params]).not_to have_key(:top_p)
      end

      it "passes temperature and top_p when ai_llm_temperature_top_p_enabled is true" do
        SiteSetting.ai_llm_temperature_top_p_enabled = true
        fake_llm = described_class.proxy(fake_model)
        fake_llm.generate("hello", user:, temperature: 0.5, top_p: 0.9)

        last_call = DiscourseAi::Completions::Endpoints::Fake.last_call
        expect(last_call[:model_params][:temperature]).to eq(0.5)
        expect(last_call[:model_params][:top_p]).to eq(0.9)
      end
    end

    context "when retrying failed requests" do
      before do
        DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:retry_jitter).returns(0)
        DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)
      end

      it "settles only the successful generation after empty failed attempts with missing usage" do
        body = success_body(content: "Answer without usage")
        body.delete(:usage)
        request =
          stub_request(:post, model.url).to_return(
            { status: 429, body: "rate limited" },
            { status: 503, body: "unavailable" },
            { status: 200, body: body.to_json },
          )
        execution =
          DiscourseAi::Completions::ExecutionContext.new(
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
          )
        expect(llm.generate("Input", user: user, execution_context: execution)).to eq(
          "Answer without usage",
        )
        expect(execution.work_budget.used).to eq(llm.tokenizer.size("Answer without usage"))
        expect(execution.work_budget.snapshot[:event_ids].size).to eq(1)
        expect(request).to have_been_requested.times(3)
      end

      it "settles provider-reported output once after empty failed attempts" do
        request =
          stub_request(:post, model.url).to_return(
            { status: 429, body: "rate limited" },
            { status: 200, body: success_body(content: "Visible", completion_tokens: 37).to_json },
          )
        execution =
          DiscourseAi::Completions::ExecutionContext.new(
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
          )
        llm.generate("Input", user: user, execution_context: execution)
        expect(execution.work_budget.used).to eq(37)
        expect(execution.work_budget.snapshot[:event_ids].size).to eq(1)
        expect(request).to have_been_requested.twice
      end

      it "uses exposed failed output as a lower bound when reported usage is only a partial snapshot" do
        partial =
          "Compare each source carefully before deciding what this evidence actually supports."
        response = instance_double(Net::HTTPResponse, code: "200")
        allow(response).to receive(:read_body) do |&block|
          block.call(
            "data: #{{ choices: [{ delta: { content: partial } }], usage: { prompt_tokens: 10, completion_tokens: 1 } }.to_json}\n\n",
          )
          raise Net::ReadTimeout, "failed after partial usage"
        end
        http = instance_double(Net::HTTP)
        allow(http).to receive(:request).and_yield(response)
        allow(FinalDestination::HTTP).to receive(:start).and_yield(http)
        execution =
          DiscourseAi::Completions::ExecutionContext.new(
            token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
          )
        expect {
          llm.generate("Input", user: user, execution_context: execution) { |_| }
        }.to raise_error(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)
        expect(execution.work_budget.used).to eq(llm.tokenizer.size(partial))
        expect(execution.token_usage_tracker.response).to eq(1)
        expect(http).to have_received(:request).once
      end

      it "settles invisible reported generation on a failed attempt without retrying it" do
        response = instance_double(Net::HTTPResponse, code: "200")
        allow(response).to receive(:read_body) do |&block|
          block.call(
            "data: #{{ choices: [], usage: { prompt_tokens: 10, completion_tokens: 37 } }.to_json}\n\n",
          )
          raise Net::ReadTimeout, "failed after reasoning usage"
        end
        http = instance_double(Net::HTTP)
        allow(http).to receive(:request).and_yield(response)
        allow(FinalDestination::HTTP).to receive(:start).and_yield(http)
        execution =
          DiscourseAi::Completions::ExecutionContext.new(
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
          )
        visible = []
        expect {
          llm.generate("Input", user: user, execution_context: execution) { |part| visible << part }
        }.to raise_error(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)
        expect(visible).to eq([])
        expect(execution.work_budget.used).to eq(37)
        expect(http).to have_received(:request).once
      end

      ["", "Visible prefix "].each do |prefix|
        it "settles #{prefix.present? ? "visible and buffered" : "buffered"} tool output on failure instead of retrying generated work" do
          model.update!(provider_params: { disable_native_tools: true })
          partial = "#{prefix}<function_calls><invoke><tool_name>read</tool_name>"
          prompt =
            DiscourseAi::Completions::Prompt.new(
              "System",
              messages: [{ type: :user, content: "Read" }],
              tools: [{ name: "read", description: "Read", parameters: [] }],
            )
          response = instance_double(Net::HTTPResponse, code: "200")
          allow(response).to receive(:read_body) do |&block|
            block.call(streaming_body(content: partial))
            raise Net::ReadTimeout, "failed after buffered output"
          end
          http = instance_double(Net::HTTP)
          allow(http).to receive(:request).and_yield(response)
          allow(FinalDestination::HTTP).to receive(:start).and_yield(http)
          execution =
            DiscourseAi::Completions::ExecutionContext.new(
              work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
            )
          visible = []
          expect {
            llm.generate(prompt, user: user, execution_context: execution) do |part|
              visible << part
            end
          }.to raise_error(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)
          expect(visible.join).to eq(prefix.strip)
          expect(execution.work_budget.used).to eq(llm.tokenizer.size(partial))
          expect(http).to have_received(:request).once
        end
      end

      it "retries rate limits three times" do
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 429, body: "rate limited" },
            { status: 429, body: "rate limited" },
            { status: 429, body: "rate limited" },
            { status: 200, body: success_body(content: "ok").to_json },
          )

        result = nil

        expect { result = llm.generate("Hello", user:) }.to change { AiApiAuditLog.count }.by(1)

        expect(result).to eq("ok")
        expect(request).to have_been_requested.times(4)
        expect(AiApiAuditLog.last.response_status).to eq(200)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 429, "delay_ms" => 0 },
            { "status" => 429, "delay_ms" => 2000 },
            { "status" => 429, "delay_ms" => 8000 },
            { "status" => 200, "delay_ms" => 16_000 },
          ],
        )
      end

      it "does not retry non-retryable client errors" do
        request =
          WebMock.stub_request(:post, model.url).to_return(status: 401, body: "unauthorized")

        expect { llm.generate("Hello", user:) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(request).to have_been_requested.once
        expect(AiApiAuditLog.last.response_status).to eq(401)
        expect(AiApiAuditLog.last.request_attempts).to be_nil
      end

      it "includes retry waits in audit duration" do
        start_time = Time.utc(2026, 1, 1, 12, 0, 0)
        current_time = start_time
        Time.stubs(:now).returns(current_time)
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with do |delay, cancel_manager|
            current_time += delay.seconds
            Time.stubs(:now).returns(current_time)
            delay == 2 && cancel_manager.nil?
          end
          .once

        WebMock.stub_request(:post, model.url).to_return(
          { status: 429, body: "rate limited" },
          { status: 200, body: success_body(content: "ok").to_json },
        )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [{ "status" => 429, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 2000 }],
        )
        expect(AiApiAuditLog.last.duration_msecs).to be >= 2000
      end

      it "respects retry-after for rate limits" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with(5, nil)
          .once

        WebMock.stub_request(:post, model.url).to_return(
          { status: 429, body: "rate limited", headers: { "Retry-After" => "5" } },
          { status: 200, body: success_body(content: "ok").to_json },
        )

        expect(llm.generate("Hello", user:)).to eq("ok")
      end

      it "respects retry-after HTTP dates for rate limits" do
        freeze_time

        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with { |delay, cancel_manager| delay.between?(29, 30) && cancel_manager.nil? }
          .once

        WebMock.stub_request(:post, model.url).to_return(
          {
            status: 429,
            body: "rate limited",
            headers: {
              "Retry-After" => 30.seconds.from_now.httpdate,
            },
          },
          { status: 200, body: success_body(content: "ok").to_json },
        )

        expect(llm.generate("Hello", user:)).to eq("ok")
      end

      it "caps retry-after values after adding jitter" do
        DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:retry_jitter).returns(1)
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with(60, nil)
          .once

        WebMock.stub_request(:post, model.url).to_return(
          { status: 429, body: "rate limited", headers: { "Retry-After" => "999999" } },
          { status: 200, body: success_body(content: "ok").to_json },
        )

        expect(llm.generate("Hello", user:)).to eq("ok")
      end

      it "raises rate limits after three retries" do
        request =
          WebMock.stub_request(:post, model.url).to_return(status: 429, body: "rate limited")

        expect { llm.generate("Hello", user:) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(request).to have_been_requested.times(4)
        expect(AiApiAuditLog.last.response_status).to eq(429)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 429, "delay_ms" => 0 },
            { "status" => 429, "delay_ms" => 2000 },
            { "status" => 429, "delay_ms" => 8000 },
            { "status" => 429, "delay_ms" => 16_000 },
          ],
        )
      end

      it "retries streaming responses after rate limits" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .stubs(:monotonic_milliseconds)
          .returns(1_000, 3_500)
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 429, body: "rate limited" },
            { status: 200, body: streaming_body(content: "Hi") },
          )

        result = +""
        llm.generate("Hello", user:) { |partial| result << partial }

        expect(result).to eq("Hi")
        expect(request).to have_been_requested.times(2)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [{ "status" => 429, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 2000 }],
        )
        expect(AiApiAuditLog.last.time_to_first_token_msecs).to eq(2500)
      end

      it "does not retry streaming responses after output has started" do
        request =
          WebMock.stub_request(:post, model.url).to_return(status: 200, body: streaming_body)

        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:streaming_response)
          .with do |kwargs|
            kwargs[:on_output_started].call
            kwargs[:blk].call("partial")
            true
          end
          .raises(Net::ReadTimeout.new("timed out"))

        result = +""
        expect { llm.generate("Hello", user:) { |partial| result << partial } }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(result).to eq("partial")
        expect(request).to have_been_requested.once
        expect(AiApiAuditLog.last.response_status).to eq(200)
        expect(AiApiAuditLog.last.request_attempts).to be_nil
      end

      it "retries streaming structured output after rate limits" do
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 429, body: "rate limited" },
            { status: 200, body: streaming_body(content: '{"message":"ok"}') },
          )

        result = nil
        llm.generate(
          "Hello",
          user:,
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
        ) { |partial| result = partial }

        expect(result).to be_a(DiscourseAi::Completions::StructuredOutput)
        expect(result.to_s).to eq('{"message":"ok"}')
        expect(request).to have_been_requested.times(2)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [{ "status" => 429, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 2000 }],
        )
      end

      it "returns structured output after rate limits" do
        WebMock.stub_request(:post, model.url).to_return(
          { status: 429, body: "rate limited" },
          { status: 200, body: success_body(content: '{"message":"ok"}').to_json },
        )

        result =
          llm.generate(
            "Hello",
            user:,
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
          )

        expect(result).to be_a(DiscourseAi::Completions::StructuredOutput)
        expect(result.to_s).to eq('{"message":"ok"}')
      end

      it "retries network errors twice" do
        request =
          WebMock
            .stub_request(:post, model.url)
            .to_raise(Net::ReadTimeout.new("timed out"))
            .then
            .to_raise(Errno::ECONNRESET.new)
            .then
            .to_return(status: 200, body: success_body(content: "ok").to_json)

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(request).to have_been_requested.times(3)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 0, "delay_ms" => 0 },
            { "status" => 0, "delay_ms" => 500 },
            { "status" => 200, "delay_ms" => 1000 },
          ],
        )
      end

      it "raises network errors after two retries" do
        request = WebMock.stub_request(:post, model.url).to_raise(Net::ReadTimeout.new("timed out"))

        expect { llm.generate("Hello", user:) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(request).to have_been_requested.times(3)
        expect(AiApiAuditLog.last.response_status).to be_nil
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 0, "delay_ms" => 0 },
            { "status" => 0, "delay_ms" => 500 },
            { "status" => 0, "delay_ms" => 1000 },
          ],
        )
      end

      it "retries request timeouts twice" do
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 408, body: "timeout" },
            { status: 408, body: "timeout" },
            { status: 200, body: success_body(content: "ok").to_json },
          )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(request).to have_been_requested.times(3)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 408, "delay_ms" => 0 },
            { "status" => 408, "delay_ms" => 500 },
            { "status" => 200, "delay_ms" => 1000 },
          ],
        )
      end

      it "retries lock timeouts twice" do
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 409, body: "conflict" },
            { status: 409, body: "conflict" },
            { status: 200, body: success_body(content: "ok").to_json },
          )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(request).to have_been_requested.times(3)
      end

      it "retries server errors twice" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with(0.5, nil)
          .once
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with(1.0, nil)
          .once

        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 503, body: "unavailable" },
            { status: 503, body: "unavailable" },
            { status: 200, body: success_body(content: "ok").to_json },
          )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(request).to have_been_requested.times(3)
      end

      it "respects retry-after for server errors" do
        DiscourseAi::Completions::Endpoints::Base
          .any_instance
          .expects(:sleep_before_retry)
          .with(5, nil)
          .once

        WebMock.stub_request(:post, model.url).to_return(
          { status: 503, body: "unavailable", headers: { "Retry-After" => "5" } },
          { status: 200, body: success_body(content: "ok").to_json },
        )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [{ "status" => 503, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 5000 }],
        )
      end

      it "tracks mixed request attempts" do
        request =
          WebMock.stub_request(:post, model.url).to_return(
            { status: 503, body: "unavailable" },
            { status: 429, body: "rate limited" },
            { status: 200, body: success_body(content: "ok").to_json },
          )

        expect(llm.generate("Hello", user:)).to eq("ok")
        expect(request).to have_been_requested.times(3)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 503, "delay_ms" => 0 },
            { "status" => 429, "delay_ms" => 500 },
            { "status" => 200, "delay_ms" => 2000 },
          ],
        )
      end

      it "raises server errors after two retries" do
        request = WebMock.stub_request(:post, model.url).to_return(status: 503, body: "unavailable")

        expect { llm.generate("Hello", user:) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
        expect(request).to have_been_requested.times(3)
        expect(AiApiAuditLog.last.response_status).to eq(503)
        expect(AiApiAuditLog.last.request_attempts).to eq(
          [
            { "status" => 503, "delay_ms" => 0 },
            { "status" => 503, "delay_ms" => 500 },
            { "status" => 503, "delay_ms" => 1000 },
          ],
        )
      end
    end

    context "when sleeping before retries" do
      it "sleeps normally without a cancel manager" do
        endpoint = DiscourseAi::Completions::Endpoints::Base.new(model)
        endpoint.expects(:sleep).with(3).once

        endpoint.send(:sleep_before_retry, 3, nil)
      end

      it "stops when cancelled" do
        cancel_manager = DiscourseAi::Completions::CancelManager.new
        endpoint = DiscourseAi::Completions::Endpoints::Base.new(model)
        waiting = Queue.new

        sleep_thread =
          Thread.new do
            waiting << true
            endpoint.send(:sleep_before_retry, 60, cancel_manager)
          end

        waiting.pop
        cancel_manager.cancel!

        expect(sleep_thread.join(1)).to eq(sleep_thread)
      ensure
        sleep_thread&.kill
      end
    end

    context "when tracking failures" do
      before do
        DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:retry_jitter).returns(0)
        DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)
      end

      it "fast-tracks problem check after threshold and resets on success" do
        WebMock.stub_request(:post, model.url).to_return(
          { status: 500, body: "fail" },
          { status: 500, body: "fail" },
          { status: 500, body: "fail" },
          { status: 500, body: "fail" },
          { status: 500, body: "fail" },
          { status: 500, body: "fail" },
          { status: 200, body: success_body.to_json },
        )

        stub_const(DiscourseAi::Completions::Endpoints::Base, "FAIL_THRESHOLD", 2) do
          2.times do
            expect { llm.generate("Hello", user:) }.to raise_error(
              DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
            )
          end
        end

        expect(ProblemCheckTracker[:ai_llm_status, model.id].reload).to be_failing
        expect { llm.generate("Hello", user:) }.not_to raise_error
        expect(Discourse.redis.get("ai_llm_status_fast_fail:#{model.id}")).to be_nil
      end

      it "skips tracking for unsaved models" do
        stub_response(status: 500, body: "fail")

        unsaved = LlmModel.new(model.attributes.except("id", "created_at", "updated_at"))

        stub_const(DiscourseAi::Completions::Endpoints::Base, "FAIL_THRESHOLD", 1) do
          expect { described_class.proxy(unsaved).generate("Hello", user:) }.to raise_error(
            DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
          )
        end
      end
    end
  end
end
