# frozen_string_literal: true

RSpec.describe Live::Reactions do
  describe ".emojis" do
    it "offers the site's post reaction set, main reaction first, when post reactions are enabled" do
      SiteSetting.discourse_reactions_enabled = true
      SiteSetting.discourse_reactions_reaction_for_like = "+1"
      SiteSetting.discourse_reactions_enabled_reactions = "+1|tada|rocket"

      expect(described_class.emojis).to eq(%w[+1 tada rocket])
    end

    it "offers the stock post reaction set when post reactions are disabled" do
      SiteSetting.discourse_reactions_enabled = false
      SiteSetting.discourse_reactions_reaction_for_like = "+1"
      SiteSetting.discourse_reactions_enabled_reactions = "tada|rocket"

      expect(described_class.emojis).to eq(
        [
          SiteSetting.defaults[:discourse_reactions_reaction_for_like],
          *SiteSetting.defaults[:discourse_reactions_enabled_reactions].split("|"),
        ],
      )
    end
  end
end
