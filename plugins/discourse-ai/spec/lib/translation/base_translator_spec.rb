# frozen_string_literal: true

describe DiscourseAi::Translation::BaseTranslator do
  let!(:agent) do
    AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::PostRawTranslator])
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_enabled = true
  end

  describe ".translate" do
    let(:text) { "cats are great" }
    let(:target_locale) { "de" }
    let(:content_description) { "A tag about cats" }
    let(:llm_response) { "hur dur hur dur!" }

    fab!(:post)
    fab!(:topic) { post.topic }

    it "sends unescaped content, post context, and the output limit to the model" do
      text = "List<string> and ?a=1&b=2"
      llm_model = Fabricate(:fake_model, max_output_tokens: 256)
      translator =
        DiscourseAi::Translation::PostRawTranslator.new(
          text:,
          target_locale:,
          content_description:,
          post:,
          topic:,
          llm_model:,
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [llm_response],
      ) do |_, _, prompts, options|
        translator.translate
        prompt = prompts.last

        expect(prompt.system_message_text).to eq(agent.system_prompt)
        expect(prompt.messages.last).to eq(
          type: :user,
          content: JSON.generate(content: text, target_locale:, content_description:),
        )
        expect([prompt.post_id, prompt.topic_id]).to eq([post.id, topic.id])
        expect(options.last[:max_tokens]).to eq(llm_model.max_output_tokens)
      end
    end

    it "fits a post by token count without charging descriptive context to the output budget" do
      llm_model = Fabricate(:fake_model, max_output_tokens: 256)
      source = "hello world " * 30
      translator =
        DiscourseAi::Translation::PostRawTranslator.new(
          text: source,
          target_locale:,
          content_description: "Background context " * 100,
          llm_model:,
        )

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do |_, _, prompts|
        expect(translator.translate).to eq(llm_response)
        expect(JSON.parse(prompts.last.messages.last[:content])["content"]).to eq(source)
      end
    end

    it "reserves output headroom and preserves all source text across requests" do
      llm_model = Fabricate(:fake_model, max_output_tokens: 128)
      source = "猫と犬が好きです。" * 40
      translator =
        DiscourseAi::Translation::PostRawTranslator.new(text: source, target_locale:, llm_model:)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(40, "translated"),
      ) do |_, _, prompts|
        result = translator.translate
        chunks = prompts.map { |prompt| JSON.parse(prompt.messages.last[:content])["content"] }

        expect(result).to eq("translated" * chunks.size)
        expect(chunks.join).to eq(source)
        expect(chunks.map { |chunk| llm_model.tokenizer_class.size(chunk) }).to all(be <= 64)
      end
    end

    it "accounts for the system prompt, examples, and content description" do
      llm_model = Fabricate(:fake_model, max_output_tokens: 8192, max_prompt_tokens: 4096)
      source = "hello world " * 3000
      translator =
        DiscourseAi::Translation::PostRawTranslator.new(
          text: source,
          target_locale:,
          content_description: "A long description " * 100,
          llm_model:,
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(40, "translated"),
      ) do |_, _, prompts, options|
        translator.translate
        chunks = prompts.map { |prompt| JSON.parse(prompt.messages.last[:content])["content"] }

        expect(chunks.join).to eq(source)
        request_tokens =
          prompts
            .zip(options)
            .map do |prompt, option|
              prompt.messages.sum { |message| llm_model.tokenizer_class.size(message[:content]) } +
                option[:max_tokens]
            end
        expect(request_tokens).to all(be <= llm_model.max_prompt_tokens)
      end
    end

    it "leaves the output limit to the provider when the model has none" do
      llm_model = Fabricate(:fake_model, max_output_tokens: nil, max_prompt_tokens: 8192)
      translator =
        DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:, llm_model:)

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do |_, _, _, options|
        expect(translator.translate).to eq(llm_response)
        expect(options.last[:max_tokens]).to be_nil
      end
    end

    it "strips control characters from the model response but keeps newlines" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["hur\u001Cdur \u001Ehur\ndur!"]) do
        expect(
          DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:).translate,
        ).to eq "hurdur hur\ndur!"
      end
    end
  end
end
