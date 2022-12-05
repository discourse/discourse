# frozen_string_literal: true

RSpec.describe Chat::ChatChannelHashtagDataSource do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:channel1) { Fabricate(:chat_channel, slug: "random", name: "Zany Things", chatable: category, description: "Just weird stuff") }
  fab!(:channel2) do
    Fabricate(:chat_channel, slug: "secret", name: "Secret Stuff", chatable: private_category)
  end
  let!(:guardian) { Guardian.new(user) }

  before { SiteSetting.enable_experimental_hashtag_autocomplete = true }

  describe "#lookup" do
    it "finds a channel by a slug" do
      result = described_class.lookup(guardian, ["random"]).first
      expect(result.to_h).to eq(
        {
          relative_url: channel1.relative_url,
          text: "Zany Things",
          description: "Just weird stuff",
          icon: "comment",
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
          type: "channel",
          ref: nil,
          slug: "secret",
        },
      )
    end
  end
end
