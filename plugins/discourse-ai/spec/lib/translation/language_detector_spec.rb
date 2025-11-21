# frozen_string_literal: true

describe DiscourseAi::Translation::LanguageDetector do
  let!(:persona) do
    AiPersona.find(
      DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::LocaleDetector],
    )
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
      expected_system_prompt = DiscourseAi::Personas::LocaleDetector.new.system_prompt

      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        expected_system_prompt,
        messages: [
          { type: :user, content: "Can you tell me what '私の世界で一番好きな食べ物はちらし丼です' means?" },
          { type: :model, content: "en" },
          {
            type: :user,
            content:
              "[quote]\nNon smettere mai di credere nella bellezza dei tuoi sogni. Anche quando tutto sembra perduto, c'è sempre una luce che aspetta di essere trovata.\nOgni passo, anche il più piccolo, ti avvicina a ciò che desideri. La forza che cerchi è già dentro di te.\n[/quote]\n¿Cuál es el mensaje principal de esta cita?",
          },
          { type: :model, content: "es" },
          { type: :user, content: "meow" },
        ],
        post_id: nil,
        topic_id: nil,
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end

    it "returns the language from the llm's response in the language tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end

    [
      ["not a language code", nil],
      ["", nil],
      ["1234", nil],
      ["en-US-INCORRECT", nil],
      %w[en-US en-US],
      %w[en en],
      %w[sr-Latn sr-Latn],
    ].each do |llm_response, expected_locale|
      it "returns #{expected_locale.inspect} when the llm responds with #{llm_response.inspect}" do
        DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
          expect(locale_detector.detect).to eq(expected_locale)
        end
      end
    end

    it "skips detection when provided blank text" do
      blank_detector = described_class.new("    ")
      allow(AiPersona).to receive(:find_by).and_call_original

      expect(blank_detector.detect).to eq(nil)
      expect(AiPersona).not_to have_received(:find_by)
    end
  end
end
