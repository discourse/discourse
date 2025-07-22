# frozen_string_literal: true

describe DiscourseAi::Translation::BaseTranslator do
  let!(:persona) do
    AiPersona.find(
      DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::PostRawTranslator],
    )
  end

  before do
    enable_current_plugin

    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end

    SiteSetting.ai_translation_enabled = true
  end

  describe ".translate" do
    let(:text) { "cats are great" }
    let(:target_locale) { "de" }
    let(:llm_response) { "hur dur hur dur!" }
    fab!(:post)
    fab!(:topic) { post.topic }

    it "creates the correct prompt" do
      post_translator =
        DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:, post:)
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        persona.system_prompt,
        messages: array_including({ type: :user, content: a_string_including(text) }),
        post_id: post.id,
        topic_id: post.topic_id,
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        post_translator.translate
      end
    end

    it "creates BotContext with the correct parameters and calls bot.reply with correct args" do
      post_translator =
        DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:, post:, topic:)

      expected_content = { content: text, target_locale: target_locale }.to_json

      bot_context = instance_double(DiscourseAi::Personas::BotContext)
      allow(DiscourseAi::Personas::BotContext).to receive(:new).and_return(bot_context)

      mock_bot = instance_double(DiscourseAi::Personas::Bot)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(mock_bot)
      allow(mock_bot).to receive(:reply).and_yield(llm_response)

      post_translator.translate

      expect(DiscourseAi::Personas::BotContext).to have_received(:new).with(
        user: an_instance_of(User),
        skip_tool_details: true,
        feature_name: "translation",
        messages: [{ type: :user, content: expected_content }],
        topic: topic,
        post: post,
      )

      expect(DiscourseAi::Personas::Bot).to have_received(:as)
      expect(mock_bot).to have_received(:reply).with(bot_context, llm_args: { max_tokens: 500 })
    end

    it "sets max_tokens correctly based on text length" do
      test_cases = [
        ["Short text", 500], # Short text (< 100 chars)
        ["a" * 200, 1000], # Medium text (100-500 chars)
        ["a" * 600, 1200], # Long text (> 500 chars, 600*2=1200)
      ]

      test_cases.each do |text, expected_max_tokens|
        translator = DiscourseAi::Translation::PostRawTranslator.new(text: text, target_locale:)

        bot_context = instance_double(DiscourseAi::Personas::BotContext)
        allow(DiscourseAi::Personas::BotContext).to receive(:new).and_return(bot_context)

        mock_bot = instance_double(DiscourseAi::Personas::Bot)
        allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(mock_bot)
        allow(mock_bot).to receive(:reply).and_yield("translated #{text[0..10]}")

        translator.translate

        expect(mock_bot).to have_received(:reply).with(
          bot_context,
          llm_args: {
            max_tokens: expected_max_tokens,
          },
        )
      end
    end

    it "returns the translation from the llm's response" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        expect(
          DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:).translate,
        ).to eq "hur dur hur dur!"
      end
    end
  end
end
