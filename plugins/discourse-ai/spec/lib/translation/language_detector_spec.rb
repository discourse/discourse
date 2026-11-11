# frozen_string_literal: true

describe DiscourseAi::Translation::LanguageDetector do
  let!(:agent) do
    AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::LocaleDetector])
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_enabled = true
  end

  describe ".detect" do
    let(:locale_detector) { described_class.new("meow") }
    let(:llm_response) { "en-US" }

    it "creates the correct prompt" do
      expected_system_prompt = DiscourseAi::Agents::LocaleDetector.new.system_prompt

      expected_messages = [
        { type: :user, content: "Can you tell me what '私の世界で一番好きな食べ物はちらし丼です' means?" },
        { type: :model, content: "en" },
        {
          type: :user,
          content:
            "[quote]\nNon smettere mai di credere nella bellezza dei tuoi sogni. Anche quando tutto sembra perduto, c'è sempre una luce che aspetta di essere trovata.\nOgni passo, anche il più piccolo, ti avvicina a ciò che desideri. La forza che cerchi è già dentro di te.\n[/quote]\n¿Cuál es el mensaje principal de esta cita?",
        },
        { type: :model, content: "es" },
        { type: :user, content: "meow" },
      ]

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do |_, _, prompts|
        expect(locale_detector.detect).to eq(llm_response)
        expect(prompts.first.system_message_text).to eq(expected_system_prompt)
        expect(prompts.first.messages.drop(1)).to eq(expected_messages)
        expect([prompts.first.post_id, prompts.first.topic_id]).to eq([nil, nil])
      end
    end

    it "rejects malformed locale responses" do
      ["not a language code", "", "1234", "en-US-INCORRECT"].each do |response|
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          expect(described_class.new("meow").detect).to be_nil
        end
      end
    end

    it "accepts language, regional and script locale tags" do
      %w[en en-US sr-Latn].each do |response|
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          expect(described_class.new("meow").detect).to eq(response)
        end
      end
    end

    it "returns the language when the streamed response has a trailing backslash" do
      bot = instance_double(DiscourseAi::Agents::Bot)
      allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
      allow(bot).to receive(:reply) { |_, &blk| blk.call("nl\\") }

      expect(locale_detector.detect).to eq("nl")
    end

    it "returns the language when the streamed response includes thinking" do
      thinking =
        DiscourseAi::Completions::Thinking.new(message: "Determining Dutch context", partial: false)

      DiscourseAi::Completions::Llm.with_prepared_responses([[thinking, "nl"]]) do
        expect(locale_detector.detect).to eq("nl")
      end
    end

    it "returns the language when the streamed response has surrounding whitespace" do
      bot = instance_double(DiscourseAi::Agents::Bot)
      allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
      allow(bot).to receive(:reply) { |_, &blk| blk.call(" nl\n") }

      expect(locale_detector.detect).to eq("nl")
    end

    it "skips detection when provided blank text" do
      blank_detector = described_class.new("    ")
      allow(AiAgent).to receive(:find_by).and_call_original

      expect(blank_detector.detect).to eq(nil)
      expect(AiAgent).not_to have_received(:find_by)
    end
  end

  describe ".detect with a decision model" do
    fab!(:decision_model) { Fabricate(:decision_model, id: -1) }

    let(:other_choice) { DiscourseAi::Translation::DecisionLocaleDetector::OTHER_CHOICE }

    before do
      SiteSetting.ai_translation_locale_detector_decision_model = decision_model.id
      SiteSetting.content_localization_supported_locales = "pt_BR|ja"
    end

    def choice(base)
      name, variants =
        DiscourseAi::Translation::DecisionLocaleDetector::COMMON_LANGUAGES.fetch(base)
      "#{name} (#{base}): #{variants}"
    end

    it "returns the site's variant of a language the model is confident about" do
      DiscourseAi::Decisions.with_canned_answers(language: { choice("pt") => 0.95 }) do |canned|
        expect(described_class.new("Dúvida sobre pagamento").detect).to eq("pt_BR")
        expect(canned.calls.first[:feature_name]).to eq("locale_detection")
      end
    end

    it "offers the site's languages beyond the common ones and truncates long text" do
      SiteSetting.content_localization_supported_locales = "pt_BR|bs_BA"
      long_text = "a" * 2000

      DiscourseAi::Decisions.with_canned_answers(
        language: "Bosnian (bs): Bosnian in any variant",
      ) do |canned|
        expect(described_class.new(long_text).detect).to eq("bs_BA")
        expect(canned.calls.first[:state].length).to eq(
          DiscourseAi::Translation::LanguageDetector::DETECTION_CHAR_LIMIT,
        )
      end
    end

    it "lets the agent decide when the language is unlisted, unsure or refused" do
      [other_choice, { choice("nl") => 0.86, other_choice => 0.14 }, :refusal].each do |answer|
        DiscourseAi::Decisions.with_canned_answers(language: answer) do
          DiscourseAi::Completions::Llm.with_prepared_responses(["af"]) do
            expect(described_class.new("Goeie môre").detect).to eq("af")
          end
        end
      end
    end

    it "lets the agent decide when the decision model request fails" do
      stub_request(:post, decision_model.url).to_return(status: 400, body: "{}")

      DiscourseAi::Completions::Llm.with_prepared_responses(["es"]) do
        expect(described_class.new("Hola").detect).to eq("es")
      end
    end

    it "detects nothing when the decision model has used up its credits" do
      Fabricate(:decision_model_credit_allocation, decision_model:, daily_used: 10_000)

      DiscourseAi::Completions::Llm.with_prepared_responses(["es"]) do |_, _, prompts|
        expect(described_class.new("Hola").detect).to be_nil
        expect(prompts).to be_empty
      end
    end
  end
end
