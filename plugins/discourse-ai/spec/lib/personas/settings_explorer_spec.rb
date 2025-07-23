# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::SettingsExplorer do
  let(:settings_explorer) { subject }

  before { enable_current_plugin }

  it "renders schema" do
    prompt = settings_explorer.system_prompt

    # check we do not render plugin settings
    expect(prompt).not_to include("ai_bot_enabled_personas")

    expect(prompt).to include("site_description")

    expect(settings_explorer.tools).to eq(
      [DiscourseAi::Personas::Tools::SettingContext, DiscourseAi::Personas::Tools::SearchSettings],
    )
  end
end
