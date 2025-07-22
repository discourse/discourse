# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Llm do
  subject(:llm) do
    described_class.new(
      DiscourseAi::Completions::Dialects::OpenAiCompatible,
      canned_response,
      model,
      gateway: canned_response,
    )
  end

  fab!(:user)
  fab!(:model) { Fabricate(:llm_model) }

  before { enable_current_plugin }

  describe ".proxy" do
    it "raises an exception when we can't proxy the model" do
      fake_model = "unknown:unknown_v2"

      expect { described_class.proxy(fake_model) }.to(
        raise_error(DiscourseAi::Completions::Llm::UNKNOWN_MODEL),
      )
    end
  end

  describe "AiApiAuditLog" do
    it "is able to keep track of post and topic id" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are fake",
          messages: [{ type: :user, content: "fake orders" }],
          topic_id: 123,
          post_id: 1,
        )

      result = <<~TEXT
        data: {"id":"chatcmpl-8xoPOYRmiuBANTmGqdCGVk4ZA3Orz","object":"chat.completion.chunk","created":1709265814,"model":"gpt-4-0125-preview","system_fingerprint":"fp_70b2088885","choices":[{"index":0,"delta":{"role":"assistant","content":""},"logprobs":null,"finish_reason":null}]}

        data: {"id":"chatcmpl-8xoPOYRmiuBANTmGqdCGVk4ZA3Orz","object":"chat.completion.chunk","created":1709265814,"model":"gpt-4-0125-preview","system_fingerprint":"fp_70b2088885","choices":[{"index":0,"delta":{"content":"Hello"},"logprobs":null,"finish_reason":null}]}

        data: [DONE]
      TEXT

      WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: result,
      )
      result = +""
      described_class
        .proxy("custom:#{model.id}")
        .generate(prompt, user: user) { |partial| result << partial }

      expect(result).to eq("Hello")
      log = AiApiAuditLog.order("id desc").first
      expect(log.topic_id).to eq(123)
      expect(log.post_id).to eq(1)
    end

    it "can track feature_name and feature_context" do
      body = {
        model: "gpt-3.5-turbo-0301",
        usage: {
          prompt_tokens: 337,
          completion_tokens: 162,
          total_tokens: 499,
        },
        choices: [
          { message: { role: "assistant", content: "test" }, finish_reason: "stop", index: 0 },
        ],
      }.to_json

      WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: body,
      )

      result =
        described_class.proxy("custom:#{model.id}").generate(
          "Hello",
          user: user,
          feature_name: "llm_triage",
          feature_context: {
            foo: "bar",
          },
        )

      expect(result).to eq("test")
      log = AiApiAuditLog.order("id desc").first
      expect(log.feature_name).to eq("llm_triage")
      expect(log.feature_context).to eq({ "foo" => "bar" })
    end
  end

  describe "#generate with fake model" do
    fab!(:fake_model)

    before do
      DiscourseAi::Completions::Endpoints::Fake.delays = []
      DiscourseAi::Completions::Endpoints::Fake.chunk_count = 10
    end

    let(:llm) { described_class.proxy("custom:#{fake_model.id}") }

    let(:prompt) do
      DiscourseAi::Completions::Prompt.new(
        "You are fake",
        messages: [{ type: :user, content: "fake orders" }],
      )
    end

    it "can generate a response" do
      response = llm.generate(prompt, user: user)
      expect(response).to be_present
    end

    it "can generate content via a block" do
      partials = []
      response = llm.generate(prompt, user: user) { |partial| partials << partial }

      expect(partials.length).to eq(10)
      expect(response).to eq(DiscourseAi::Completions::Endpoints::Fake.fake_content)

      expect(partials.join).to eq(response)
    end
  end

  describe "#generate with various style prompts" do
    let :canned_response do
      DiscourseAi::Completions::Endpoints::CannedResponse.new(["world"])
    end

    it "can generate a response to a simple string" do
      response = llm.generate("hello", user: user)
      expect(response).to eq("world")
    end

    it "can generate a response from an array" do
      response =
        llm.generate(
          [{ type: :system, content: "you are a bot" }, { type: :user, content: "hello" }],
          user: user,
        )
      expect(response).to eq("world")
    end
  end

  describe "#generate" do
    let(:prompt) do
      system_insts = (<<~TEXT).strip
      I want you to act as a title generator for written pieces. I will provide you with a text,
      and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
      and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
      TEXT

      DiscourseAi::Completions::Prompt
        .new(system_insts)
        .tap { |a_prompt| a_prompt.push(type: :user, content: (<<~TEXT).strip) }
          Here is the text, inside <input></input> XML tags:
          <input>
            To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
            discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
            defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.
          </input>
          TEXT
    end

    let(:canned_response) do
      DiscourseAi::Completions::Endpoints::CannedResponse.new(
        [
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      )
    end

    context "when getting the full response" do
      it "processes the prompt and return the response" do
        llm_response = llm.generate(prompt, user: user)

        expect(llm_response).to eq(canned_response.responses[0])
      end
    end

    context "when getting a streamed response" do
      it "processes the prompt and call the given block with the partial response" do
        llm_response = +""

        llm.generate(prompt, user: user) { |partial, cancel_fn| llm_response << partial }

        expect(llm_response).to eq(canned_response.responses[0])
      end
    end
  end
end
