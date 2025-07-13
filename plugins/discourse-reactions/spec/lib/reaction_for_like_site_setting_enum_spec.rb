# frozen_string_literal: true

RSpec.describe ReactionForLikeSiteSettingEnum do
  it "does not allow using any discourse_reactions_excluded_from_like emojis" do
    expect(described_class.valid_value?("-1")).to eq(false)
    expect(described_class.valid_value?("heart")).to eq(true)
    expect(described_class.valid_value?("clap")).to eq(true)
  end

  it "only allows using discourse_reactions_enabled_reactions or the default" do
    SiteSetting.discourse_reactions_enabled_reactions = "clap|laughing"
    expect(described_class.valid_value?("heart")).to eq(true)
    expect(described_class.valid_value?("clap")).to eq(true)
    expect(described_class.valid_value?("tickets")).to eq(false)
  end
end
