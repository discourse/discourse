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

  describe ".valid?" do
    before do
      SiteSetting.discourse_reactions_enabled = true
      SiteSetting.discourse_reactions_reaction_for_like = "heart"
      SiteSetting.discourse_reactions_enabled_reactions = "clap"
    end

    it "accepts only the reaction set when any emoji isn't allowed" do
      SiteSetting.discourse_reactions_allow_any_emoji = false

      expect(%w[heart clap rocket].map { described_class.valid?(_1) }).to eq([true, true, false])
    end

    it "accepts any existing emoji, toned ones included, when any emoji is allowed" do
      SiteSetting.discourse_reactions_allow_any_emoji = true

      expect(%w[rocket clap:t3 not_an_emoji].map { described_class.valid?(_1) }).to eq(
        [true, true, false],
      )
    end

    it "rejects non-strings and names that aren't shortcode-shaped when any emoji is allowed" do
      SiteSetting.discourse_reactions_allow_any_emoji = true

      expect(
        [["rocket"], { "a" => "b" }, "Rocket", "rocket!", "a" * 101].map do
          described_class.valid?(_1)
        end,
      ).to all(eq(false))
    end

    it "ignores the any emoji setting while post reactions are disabled" do
      SiteSetting.discourse_reactions_allow_any_emoji = true
      SiteSetting.discourse_reactions_enabled = false

      expect(described_class.allow_any_emoji?).to eq(false)
      expect(described_class.valid?("rocket")).to eq(false)
    end
  end
end
