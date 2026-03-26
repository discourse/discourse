# frozen_string_literal: true

RSpec.describe DiscourseTopicVoting::Categories::Types::Ideas do
  fab!(:category)

  before { SiteSetting.topic_voting_enabled = true }

  describe ".visible?" do
    it "returns true when enable_ideas_category_type_setup is true" do
      SiteSetting.enable_ideas_category_type_setup = true
      expect(described_class.visible?).to eq(true)
    end

    it "returns false when enable_ideas_category_type_setup is false" do
      SiteSetting.enable_ideas_category_type_setup = false
      expect(described_class.visible?).to eq(false)
    end
  end

  describe ".enable_plugin" do
    it "enables the topic_voting_enabled site setting" do
      SiteSetting.topic_voting_enabled = false
      described_class.enable_plugin
      expect(SiteSetting.topic_voting_enabled).to eq(true)
    end
  end

  describe ".category_matches?" do
    it "returns true when category has voting enabled" do
      DiscourseTopicVoting::CategorySetting.create!(category: category)
      Category.reset_voting_cache
      expect(described_class.category_matches?(category)).to eq(true)
    end

    it "returns false when category does not have voting enabled" do
      Category.reset_voting_cache
      expect(described_class.category_matches?(category)).to eq(false)
    end
  end

  describe ".find_matches" do
    it "returns categories with voting enabled" do
      DiscourseTopicVoting::CategorySetting.create!(category: category)
      expect(described_class.find_matches).to include(category)
    end

    it "does not return categories without voting" do
      expect(described_class.find_matches).not_to include(category)
    end
  end

  describe ".configure_category" do
    fab!(:admin)

    it "creates a topic_voting_category_setting record" do
      expect { described_class.configure_category(category, guardian: admin.guardian) }.to change {
        DiscourseTopicVoting::CategorySetting.count
      }.by(1)

      expect(Category.can_vote?(category.id)).to eq(true)
    end

    it "does not create duplicate records" do
      described_class.configure_category(category, guardian: admin.guardian)

      expect {
        described_class.configure_category(category, guardian: admin.guardian)
      }.not_to change { DiscourseTopicVoting::CategorySetting.count }
    end
  end

  describe ".configuration_schema" do
    it "returns expected keys" do
      schema = described_class.configuration_schema
      expect(schema).to have_key(:general_category_settings)
      expect(schema).to have_key(:site_settings)
    end

    it "includes general category settings with correct defaults" do
      schema = described_class.configuration_schema
      expect(schema[:general_category_settings][:name][:default]).to eq("Ideas")
      expect(schema[:general_category_settings][:emoji][:default]).to eq("bulb")
    end

    it "includes site settings for visibility, vote limits toggle, and vote limits" do
      schema = described_class.configuration_schema
      site_settings = schema[:site_settings].except(:labels)
      expect(site_settings).to eq(
        {
          topic_voting_show_who_voted: true,
          topic_voting_show_votes_on_profile: true,
          topic_voting_enable_vote_limits: true,
          topic_voting_tl0_vote_limit: {
            default: 2,
            depends_on: :topic_voting_enable_vote_limits,
          },
          topic_voting_tl1_vote_limit: {
            default: 4,
            depends_on: :topic_voting_enable_vote_limits,
          },
          topic_voting_tl2_vote_limit: {
            default: 6,
            depends_on: :topic_voting_enable_vote_limits,
          },
          topic_voting_tl3_vote_limit: {
            default: 8,
            depends_on: :topic_voting_enable_vote_limits,
          },
          topic_voting_tl4_vote_limit: {
            default: 10,
            depends_on: :topic_voting_enable_vote_limits,
          },
          topic_voting_alert_votes_left: {
            default: 1,
            depends_on: :topic_voting_enable_vote_limits,
          },
        },
      )
    end

    it "includes labels for all site settings" do
      schema = described_class.configuration_schema
      labels = schema[:site_settings][:labels]
      expect(labels.keys).to match_array(schema[:site_settings].except(:labels).keys)
      expect(labels[:topic_voting_show_who_voted]).to eq("Show who voted")
      expect(labels[:topic_voting_enable_vote_limits]).to eq("Limit member votes")
    end
  end
end
