# frozen_string_literal: true

RSpec.describe Chat::ChannelHashtagDataSource do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:channel1) do
    Fabricate(
      :chat_channel,
      slug: "random",
      name: "Zany Things",
      chatable: category,
      description: "Just weird stuff",
      messages_count: 245,
    )
  end
  fab!(:channel2) do
    Fabricate(
      :chat_channel,
      slug: "secret",
      name: "Secret Stuff",
      chatable: private_category,
      messages_count: 78,
    )
  end
  let!(:guardian) { Guardian.new(user) }

  before do
    SiteSetting.enable_experimental_hashtag_autocomplete = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
    Group.refresh_automatic_groups!
  end

  describe "#enabled?" do
    it "returns false if public channels are disabled" do
      SiteSetting.enable_public_channels = false
      expect(described_class.enabled?).to eq(false)
    end

    it "returns true if public channels are disabled" do
      SiteSetting.enable_public_channels = true
      expect(described_class.enabled?).to eq(true)
    end
  end

  describe "#lookup" do
    it "finds a channel by a slug" do
      result = described_class.lookup(guardian, ["random"]).first
      expect(result.to_h).to eq(
        {
          relative_url: channel1.relative_url,
          text: "Zany Things",
          description: "Just weird stuff",
          icon: "comment",
          id: channel1.id,
          type: "channel",
          ref: nil,
          slug: "random",
        },
      )
    end

    it "does not return a channel that a user does not have permission to view" do
      result = described_class.lookup(guardian, ["secret"]).first
      expect(result).to eq(nil)

      GroupUser.create(user: user, group: group)
      result = described_class.lookup(Guardian.new(user), ["secret"]).first
      expect(result.to_h).to eq(
        {
          relative_url: channel2.relative_url,
          text: "Secret Stuff",
          description: nil,
          icon: "comment",
          id: channel2.id,
          type: "channel",
          ref: nil,
          slug: "secret",
        },
      )
    end

    it "returns nothing if the slugs array is empty" do
      result = described_class.lookup(guardian, []).first
      expect(result).to eq(nil)
    end

    it "returns nothing if the user cannot chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
      Group.refresh_automatic_groups!
      expect(described_class.lookup(Guardian.new(user), ["random"])).to be_empty
    end
  end

  describe "#search" do
    it "does not find channels by category name" do
      category.update!(name: "Randomizer")
      result = described_class.search(guardian, "randomiz", 10).first
      expect(result.to_h).to eq({})
    end

    it "finds a channel by slug" do
      result = described_class.search(guardian, "rand", 10).first
      expect(result.to_h).to eq(
        {
          relative_url: channel1.relative_url,
          text: "Zany Things",
          description: "Just weird stuff",
          icon: "comment",
          id: channel1.id,
          type: "channel",
          ref: nil,
          slug: "random",
        },
      )
    end

    it "finds a channel by channel name" do
      result = described_class.search(guardian, "aNY t", 10).first
      expect(result.to_h).to eq(
        {
          relative_url: channel1.relative_url,
          text: "Zany Things",
          description: "Just weird stuff",
          icon: "comment",
          id: channel1.id,
          type: "channel",
          ref: nil,
          slug: "random",
        },
      )
    end

    it "does not return channels the user does not have permission to view" do
      result = described_class.search(guardian, "Sec", 10).first
      expect(result).to eq(nil)
      GroupUser.create(user: user, group: group)
      result = described_class.search(Guardian.new(user), "Sec", 10).first
      expect(result.to_h).to eq(
        {
          relative_url: channel2.relative_url,
          text: "Secret Stuff",
          description: nil,
          icon: "comment",
          id: channel2.id,
          type: "channel",
          ref: nil,
          slug: "secret",
        },
      )
    end

    it "returns nothing if the user cannot chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
      Group.refresh_automatic_groups!
      expect(described_class.search(Guardian.new(user), "rand", 10)).to be_empty
    end
  end

  describe "#search_without_term" do
    fab!(:channel3) { Fabricate(:chat_channel, slug: "general", messages_count: 24) }
    fab!(:channel4) { Fabricate(:chat_channel, slug: "chat", messages_count: 435) }
    fab!(:channel5) { Fabricate(:chat_channel, slug: "code-review", messages_count: 334) }
    fab!(:membership2) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel1)
    end
    fab!(:membership2) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel2)
    end
    fab!(:membership3) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel3)
    end
    fab!(:membership4) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel4)
    end
    fab!(:membership5) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel5)
    end

    it "returns distinct channels for messages that have been recently created in the past 2 weeks" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(
        %w[chat code-review random general],
      )
    end

    it "does not return channels the user does not have permission to view" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("secret")
    end

    it "does not return channels where the user is not following the channel via user_chat_channel_memberships" do
      membership5.destroy
      membership3.update!(following: false)
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(%w[chat random])
    end

    it "returns nothing if the user cannot chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
      Group.refresh_automatic_groups!
      expect(described_class.search_without_term(Guardian.new(user), 10)).to be_empty
    end
  end

  describe "#search_sort" do
    it "orders by exact slug match, starts with, then text" do
      results_to_sort = [
        HashtagAutocompleteService::HashtagItem.new(
          text: "System Tests",
          slug: "system-test-development",
        ),
        HashtagAutocompleteService::HashtagItem.new(text: "Ruby Dev", slug: "ruby-dev"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev", slug: "dev"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev Tools", slug: "dev-tools"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev Lore", slug: "dev-lore"),
      ]
      expect(described_class.search_sort(results_to_sort, "dev").map(&:slug)).to eq(
        %w[dev dev-lore dev-tools ruby-dev system-test-development],
      )
    end
  end
end
