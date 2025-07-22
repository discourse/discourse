# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Assistant do
  fab!(:user)
  fab!(:empty_locale_user) { Fabricate(:user, locale: "") }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_helper_model)
    Group.refresh_automatic_groups!
  end

  let(:english_text) { <<~STRING }
    To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
    discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
    defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.
  STRING

  describe("#custom_locale_instructions") do
    it "Properly generates the per locale system instruction" do
      SiteSetting.default_locale = "ko"
      expect(subject.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )

      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(subject.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Hebrew (עברית), you are interacting with a Hebrew (עברית) speaking user. Leave tag names in English.",
      )
    end

    it "returns sytstem instructions using Site locale if force_default_locale is true" do
      SiteSetting.default_locale = "ko"
      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(subject.custom_locale_instructions(user, true)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )
    end
  end

  describe("#available_prompts") do
    before do
      SiteSetting.ai_helper_illustrate_post_model = "disabled"
      DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
    end

    it "returns all available prompts" do
      prompts = subject.available_prompts(user)

      expect(prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "generate_titles",
        "proofread",
        "markdown_table",
        "explain",
        "replace_dates",
      )
    end

    it "returns all prompts to be shown in the composer" do
      prompts = subject.available_prompts(user)
      filtered_prompts = prompts.select { |prompt| prompt[:location].include?("composer") }

      expect(filtered_prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "generate_titles",
        "proofread",
        "markdown_table",
        "replace_dates",
      )
    end

    it "returns all prompts to be shown in the post menu" do
      prompts = subject.available_prompts(user)
      filtered_prompts = prompts.select { |prompt| prompt[:location].include?("post") }

      expect(filtered_prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "explain",
        "proofread",
      )
    end

    it "does not raise an error when effective_locale does not exactly match keys in LocaleSiteSetting" do
      SiteSetting.default_locale = "zh_CN"
      expect { subject.available_prompts(user) }.not_to raise_error
    end

    context "when illustrate post model is enabled" do
      before do
        SiteSetting.ai_helper_illustrate_post_model = "stable_diffusion_xl"
        DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
      end

      it "returns the illustrate_post prompt in the list of all prompts" do
        prompts = subject.available_prompts(user)

        expect(prompts.map { |p| p[:name] }).to contain_exactly(
          "translate",
          "generate_titles",
          "proofread",
          "markdown_table",
          "explain",
          "illustrate_post",
          "replace_dates",
        )
      end
    end
  end

  describe("#attach_user_context") do
    before { SiteSetting.allow_user_locale = true }

    let(:context) { DiscourseAi::Personas::BotContext.new(user: user) }

    it "is able to perform %LANGUAGE% replacements" do
      subject.attach_user_context(context, user)

      expect(context.user_language).to eq("English (US)")
    end

    it "handles users with empty string locales" do
      subject.attach_user_context(context, empty_locale_user)

      expect(context.user_language).to eq("English (US)")
    end

    context "with temporal context" do
      it "replaces temporal context with timezone information" do
        timezone = "America/New_York"
        user.user_option.update!(timezone: timezone)
        freeze_time "2024-01-01 12:00:00"

        subject.attach_user_context(context, user)

        expect(context.temporal_context).to include(%("timezone":"America/New_York"))
      end

      it "uses UTC as default timezone when user timezone is not set" do
        user.user_option.update!(timezone: nil)

        freeze_time "2024-01-01 12:00:00" do
          subject.attach_user_context(context, user)

          parsed_context = JSON.parse(context.temporal_context)
          expect(parsed_context.dig("user", "timezone")).to eq("UTC")
        end
      end

      it "does not replace temporal context when user is nil" do
        subject.attach_user_context(context, nil)

        expect(context.temporal_context).to be_nil
      end
    end
  end

  describe "#generate_and_send_prompt" do
    context "when using a prompt that returns text" do
      let(:mode) { described_class::TRANSLATE }

      let(:text_to_translate) { <<~STRING }
        Para que su horror sea perfecto, César, acosado al pie de la estatua por lo impacientes puñales de sus amigos,
        descubre entre las caras y los aceros la de Marco Bruto, su protegido, acaso su hijo,
        y ya no se defiende y exclama: ¡Tú también, hijo mío! Shakespeare y Quevedo recogen el patético grito.
      STRING

      it "Sends the prompt to the LLM and returns the response" do
        response =
          DiscourseAi::Completions::Llm.with_prepared_responses([english_text]) do
            subject.generate_and_send_prompt(mode, text_to_translate, user)
          end

        expect(response[:suggestions]).to contain_exactly(english_text)
      end

      context "when the persona is not using structured outputs" do
        it "still works" do
          regular_persona = Fabricate(:ai_persona, response_format: nil)
          SiteSetting.ai_helper_translator_persona = regular_persona.id

          response =
            DiscourseAi::Completions::Llm.with_prepared_responses([english_text]) do
              subject.generate_and_send_prompt(mode, text_to_translate, user)
            end

          expect(response[:suggestions]).to contain_exactly(english_text)
        end
      end
    end

    context "when using a prompt that returns a list" do
      let(:mode) { described_class::GENERATE_TITLES }

      let(:titles) do
        {
          output: [
            "The solitary horse",
            "The horse etched in gold",
            "A horse's infinite journey",
            "A horse lost in time",
            "A horse's last ride",
          ],
        }
      end

      it "returns an array with each title" do
        expected = [
          "The solitary horse",
          "The horse etched in gold",
          "A horse's infinite journey",
          "A horse lost in time",
          "A horse's last ride",
        ]

        response =
          DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
            subject.generate_and_send_prompt(mode, english_text, user)
          end

        expect(response[:suggestions]).to contain_exactly(*expected)
      end
    end
  end
end
