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
      data: {"id":"1","object":"chat.completion.chunk","choices":[{"delta":{"content":"#{content}"}}]}

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

    context "when tracking failures" do
      it "fast-tracks problem check after threshold and resets on success" do
        WebMock.stub_request(:post, model.url).to_return(
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
