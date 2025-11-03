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
    let(:llm_response) { "hur dur hur dur!" }

    it "creates the correct prompt" do
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        persona.system_prompt,
        messages: [{ type: :user, content: "meow", id: "user" }],
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end

    it "sends the language detection prompt to the ai helper model" do
      mock_prompt = instance_double(DiscourseAi::Completions::Prompt)
      mock_llm = instance_double(DiscourseAi::Completions::Llm)

      structured_output =
        DiscourseAi::Completions::StructuredOutput.new({ locale: { type: "string" } })
      structured_output << { locale: llm_response }.to_json

      allow(DiscourseAi::Completions::Prompt).to receive(:new).and_return(mock_prompt)
      allow(DiscourseAi::Completions::Llm).to receive(:proxy).with(
        SiteSetting.ai_default_llm_model,
      ).and_return(mock_llm)
      allow(mock_llm).to receive(:generate).with(
        mock_prompt,
        user: Discourse.system_user,
        feature_name: "translation",
        response_format: persona.response_format,
      ).and_return(structured_output)

      locale_detector.detect
    end

    it "returns the language from the llm's response in the language tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        locale_detector.detect
      end
    end

    it "returns nil when the llm's response is not a valid language tag" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["not a language code"]) do
        expect(locale_detector.detect).to eq(nil)
      end

      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        expect(locale_detector.detect).to eq(nil)
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["1234"]) do
        expect(locale_detector.detect).to eq(nil)
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["en-US-INCORRECT"]) do
        expect(locale_detector.detect).to eq(nil)
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["en-US-INCORRECT"]) do
        expect(locale_detector.detect).to eq(nil)
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["en-US"]) do
        expect(locale_detector.detect).to eq("en-US")
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["en"]) do
        expect(locale_detector.detect).to eq("en")
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["sr-Latn"]) do
        expect(locale_detector.detect).to eq("sr-Latn")
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
