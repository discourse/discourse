# frozen_string_literal: true

RSpec.describe ReactionsExcludedFromLikeSiteSettingValidator do
  it "does not allow the value of discourse_reactions_reaction_for_like to be used" do
    expect(described_class.new.valid_value?("clap|heart")).to eq(false)
    expect(described_class.new.valid_value?("clap")).to eq(true)
  end

  it "does not allow any emojis not in discourse_reactions_enabled_reactions to be used except the default" do
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|open_mouth"
    expect(described_class.new.valid_value?("clap")).to eq(false)
    expect(described_class.new.valid_value?("laughing")).to eq(true)
    expect(described_class.new.valid_value?("-1")).to eq(true)
    expect(described_class.new.valid_value?("-1|laughing")).to eq(true)
  end
end
