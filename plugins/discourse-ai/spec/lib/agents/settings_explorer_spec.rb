# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::SettingsExplorer do
  subject(:settings_explorer) { described_class.new }

  before { enable_current_plugin }

  it "instructs the agent to look up current setting values" do
    expect(settings_explorer.system_prompt).to include(
      "You are able to look up the current value of a site setting.",
    )
  end

  it "requires human approval before updating settings for administrators" do
    expect(settings_explorer.system_prompt).to include(
      "You are able to update site settings when an administrator asks you to do so, but you must get approval from a human before making any change.",
    )
  end

  it "renders schema" do
    prompt = settings_explorer.system_prompt

    # check we do not render plugin settings
    expect(prompt).not_to include("ai_bot_enabled_agents")

    expect(prompt).to include("site_description")

    expect(settings_explorer.tools).to eq(
      [
        DiscourseAi::Agents::Tools::SettingContext,
        DiscourseAi::Agents::Tools::SearchSettings,
        DiscourseAi::Agents::Tools::ReadSiteSetting,
        DiscourseAi::Agents::Tools::ChangeSiteSetting,
      ],
    )
  end
end
