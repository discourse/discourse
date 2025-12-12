# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Assistant do
  subject(:assistant) { described_class.new }

  fab!(:user)
  fab!(:empty_locale_user) { Fabricate(:user, locale: "") }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
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
      expect(assistant.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )

      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(assistant.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Hebrew (עברית), you are interacting with a Hebrew (עברית) speaking user. Leave tag names in English.",
      )
    end

    it "returns sytstem instructions using Site locale if force_default_locale is true" do
      SiteSetting.default_locale = "ko"
      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(assistant.custom_locale_instructions(user, true)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )
    end
  end

  describe("#available_prompts") do
    before { DiscourseAi::AiHelper::Assistant.clear_prompt_cache! }

    it "returns all available prompts" do
      prompts = assistant.available_prompts(user)

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
      prompts = assistant.available_prompts(user)
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
      prompts = assistant.available_prompts(user)
      filtered_prompts = prompts.select { |prompt| prompt[:location].include?("post") }

      expect(filtered_prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "explain",
        "proofread",
      )
    end

    it "does not raise an error when effective_locale does not exactly match keys in LocaleSiteSetting" do
      SiteSetting.default_locale = "zh_CN"
      expect { assistant.available_prompts(user) }.not_to raise_error
    end

    context "when PostIllustrator persona has an image generation tool" do
      let(:image_tool) do
        AiTool.create!(
          name: "Test Image Generator",
          tool_name: "test_image_generator",
          description: "Generates test images",
          summary: "Test image generation",
          parameters: [{ name: "prompt", type: "string", required: true }],
          script: <<~JS,
            function invoke(params) {
              const image = upload.create("test.png", "base64data");
              chain.setCustomRaw(`![test](${image.short_url})`);
              return { result: "success" };
            }
          JS
          created_by_id: user.id,
        )
      end

      context "with system PostIllustrator persona (dynamic tool discovery)" do
        before do
          # Use the default system PostIllustrator persona
          image_tool # Create the tool
          DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
        end

        it "automatically discovers and uses the image generation tool" do
          prompts = assistant.available_prompts(user)

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

        it "PostIllustrator persona has tools and forces their use" do
          persona = AiPersona.find_by(id: SiteSetting.ai_helper_post_illustrator_persona)
          persona_instance = persona.class_instance.new

          expect(persona_instance.tools).not_to be_empty
          expect(persona_instance.tools.first).to be_a(Class)
          expect(persona_instance.tools.first.tool_id).to eq(image_tool.id)
          expect(persona_instance.force_tool_use).to eq(persona_instance.tools)
          expect(persona_instance.forced_tool_count).to eq(1)
        end
      end

      context "with custom persona" do
        let(:custom_persona) do
          AiPersona.create!(
            name: "Custom Post Illustrator",
            description: "Test persona with image tool",
            system_prompt: "You are an AI that generates images from text prompts.",
            enabled: true,
            system: false,
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
            tools: [["custom-#{image_tool.id}", {}, true]],
          )
        end

        before do
          # Set the custom persona as the illustrator persona
          SiteSetting.ai_helper_post_illustrator_persona = custom_persona.id
          DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
        end

        it "returns the illustrate_post prompt in the list of all prompts" do
          prompts = assistant.available_prompts(user)

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

      context "when handling edge cases" do
        before { DiscourseAi::AiHelper::Assistant.clear_prompt_cache! }

        it "does not include illustrate_post when no image generation tools are enabled" do
          # Disable all image generation tools
          AiTool.where(is_image_generation_tool: true).update_all(enabled: false)
          DiscourseAi::AiHelper::Assistant.clear_prompt_cache!

          prompts = assistant.available_prompts(user)

          expect(prompts.map { |p| p[:name] }).not_to include("illustrate_post")
        end

        it "handles tool discovery returning empty array" do
          # Create a tool that looks like an image tool but isn't
          AiTool.create!(
            name: "Not An Image Tool",
            tool_name: "not_image_tool",
            description: "Not an image tool",
            summary: "Test",
            parameters: [{ name: "text", type: "string" }],
            script: "function invoke() { return {}; }",
            created_by_id: user.id,
            enabled: true,
            is_image_generation_tool: false,
          )

          DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
          prompts = assistant.available_prompts(user)

          expect(prompts.map { |p| p[:name] }).not_to include("illustrate_post")
        end

        it "gracefully handles PostIllustrator.tools raising exception" do
          # Stub the PostIllustrator class to raise an error
          allow_any_instance_of(DiscourseAi::Personas::PostIllustrator).to receive(
            :tools,
          ).and_raise(StandardError.new("Tool discovery failed"))

          DiscourseAi::AiHelper::Assistant.clear_prompt_cache!

          # Should not raise error, just exclude illustrate_post
          expect { assistant.available_prompts(user) }.not_to raise_error
          prompts = assistant.available_prompts(user)
          expect(prompts.map { |p| p[:name] }).not_to include("illustrate_post")
        end
      end
    end
  end

  describe("#attach_user_context") do
    before { SiteSetting.allow_user_locale = true }

    let(:context) { DiscourseAi::Personas::BotContext.new(user: user) }

    it "is able to perform %LANGUAGE% replacements" do
      assistant.attach_user_context(context, user)

      expect(context.user_language).to eq("English (US)")
    end

    it "handles users with empty string locales" do
      assistant.attach_user_context(context, empty_locale_user)

      expect(context.user_language).to eq("English (US)")
    end

    context "with temporal context" do
      it "replaces temporal context with timezone information" do
        timezone = "America/New_York"
        user.user_option.update!(timezone: timezone)
        freeze_time "2024-01-01 12:00:00"

        assistant.attach_user_context(context, user)

        expect(context.temporal_context).to include(%("timezone":"America/New_York"))
      end

      it "uses UTC as default timezone when user timezone is not set" do
        user.user_option.update!(timezone: nil)

        freeze_time "2024-01-01 12:00:00" do
          assistant.attach_user_context(context, user)

          parsed_context = JSON.parse(context.temporal_context)
          expect(parsed_context.dig("user", "timezone")).to eq("UTC")
        end
      end

      it "does not replace temporal context when user is nil" do
        assistant.attach_user_context(context, nil)

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
            assistant.generate_and_send_prompt(mode, text_to_translate, user)
          end

        expect(response[:suggestions]).to contain_exactly(english_text)
      end

      context "when the persona is not using structured outputs" do
        it "still works" do
          regular_persona = Fabricate(:ai_persona, response_format: nil)
          SiteSetting.ai_helper_translator_persona = regular_persona.id

          response =
            DiscourseAi::Completions::Llm.with_prepared_responses([english_text]) do
              assistant.generate_and_send_prompt(mode, text_to_translate, user)
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
            assistant.generate_and_send_prompt(mode, english_text, user)
          end

        expect(response[:suggestions]).to contain_exactly(*expected)
      end
    end
  end
end
