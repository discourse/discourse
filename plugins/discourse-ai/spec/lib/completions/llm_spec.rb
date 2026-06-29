# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Llm do
  fab!(:user)
  fab!(:model, :llm_model)

  let(:llm) { described_class.proxy(model) }

  before { enable_current_plugin }

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

  describe ".proxy" do
    it "raises for unknown model identifiers" do
      expect { described_class.proxy("unknown:v2") }.to raise_error(described_class::UNKNOWN_MODEL)
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
        expect(AiApiAuditLog.last).to have_attributes(response_status: 401, response_tokens: 0)
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

      it "caps unreasonable retry-after values" do
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
