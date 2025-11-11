# frozen_string_literal: true

describe DiscourseAi::AiHelper::EntryPoint do
  fab!(:english_user, :user)
  fab!(:french_user) { Fabricate(:user, locale: "fr") }

  before { enable_current_plugin }

  it "will correctly localize available prompts" do
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.default_locale = "en"
    SiteSetting.allow_user_locale = true
    SiteSetting.ai_helper_enabled = true
    SiteSetting.composer_ai_helper_allowed_groups = "10" # tl0
    DiscourseAi::AiHelper::Assistant.clear_prompt_cache!

    Group.refresh_automatic_groups!

    serializer = CurrentUserSerializer.new(english_user, scope: Guardian.new(english_user))
    parsed = JSON.parse(serializer.to_json)

    translate_prompt =
      parsed["current_user"]["ai_helper_prompts"].find { |prompt| prompt["name"] == "translate" }

    expect(translate_prompt["translated_name"]).to eq(
      I18n.t("discourse_ai.ai_helper.prompts.translate", language: "English (US)"),
    )

    I18n.with_locale("fr") do
      serializer = CurrentUserSerializer.new(french_user, scope: Guardian.new(french_user))
      parsed = JSON.parse(serializer.to_json)

      translate_prompt =
        parsed["current_user"]["ai_helper_prompts"].find { |prompt| prompt["name"] == "translate" }

      expect(translate_prompt["translated_name"]).to eq(
        I18n.t("discourse_ai.ai_helper.prompts.translate", locale: "fr", language: "Français"),
      )
    end
  end
end
