# frozen_string_literal: true

require "rails_helper"
require_relative "../dummy_provider"

RSpec.describe DiscourseChatIntegration::Rule do
  include_context "with dummy provider"

  let(:tag1) { Fabricate(:tag) }
  let(:tag2) { Fabricate(:tag) }

  let(:channel) { DiscourseChatIntegration::Channel.create(provider: "dummy") }
  let(:category) { Fabricate(:category) }
  let(:group) { Fabricate(:group) }

  describe ".alloc_key" do
    it "should return sequential numbers" do
      expect(DiscourseChatIntegration::Rule.create(channel: channel).key).to eq("rule:1")
      expect(DiscourseChatIntegration::Rule.create(channel: channel).key).to eq("rule:2")
      expect(DiscourseChatIntegration::Rule.create(channel: channel).key).to eq("rule:3")
    end
  end

  it "should convert between channel and channel_id successfully" do
    rule = DiscourseChatIntegration::Rule.create(channel: channel)
    expect(rule.channel_id).to eq(channel.id)
    expect(rule.channel.id).to eq(channel.id)
  end

  it "should save and load successfully" do
    expect(DiscourseChatIntegration::Rule.all.length).to eq(0)

    rule =
      DiscourseChatIntegration::Rule.create(
        channel: channel,
        category_id: category.id,
        tags: [tag1.name, tag2.name],
        filter: "watch",
      )

    expect(DiscourseChatIntegration::Rule.all.length).to eq(1)

    loadedRule = DiscourseChatIntegration::Rule.find(rule.id)

    expect(loadedRule.channel.id).to eq(channel.id)
    expect(loadedRule.category_id).to eq(category.id)
    expect(loadedRule.tags).to contain_exactly(tag1.name, tag2.name)
    expect(loadedRule.filter).to eq("watch")
  end

  describe "general operations" do
    before do
      rule =
        DiscourseChatIntegration::Rule.create(
          channel: channel,
          category_id: category.id,
          tags: [tag1.name, tag2.name],
        )
    end

    it "can be modified" do
      rule = DiscourseChatIntegration::Rule.all.first
      rule.tags = [tag1.name]

      rule.save!

      rule = DiscourseChatIntegration::Rule.all.first
      expect(rule.tags).to contain_exactly(tag1.name)
    end

    it "can be deleted" do
      DiscourseChatIntegration::Rule.new(channel: channel).save!
      expect(DiscourseChatIntegration::Rule.all.length).to eq(2)

      rule = DiscourseChatIntegration::Rule.all.first
      rule.destroy

      expect(DiscourseChatIntegration::Rule.all.length).to eq(1)
    end

    it "can delete all" do
      DiscourseChatIntegration::Rule.create(channel: channel)
      DiscourseChatIntegration::Rule.create(channel: channel)
      DiscourseChatIntegration::Rule.create(channel: channel)
      DiscourseChatIntegration::Rule.create(channel: channel)

      expect(DiscourseChatIntegration::Rule.all.length).to eq(5)

      DiscourseChatIntegration::Rule.destroy_all

      expect(DiscourseChatIntegration::Rule.all.length).to eq(0)
    end

    it "can be filtered by channel" do
      channel2 = DiscourseChatIntegration::Channel.create(provider: "dummy")
      channel3 = DiscourseChatIntegration::Channel.create(provider: "dummy")

      rule2 = DiscourseChatIntegration::Rule.create(channel: channel)
      rule3 = DiscourseChatIntegration::Rule.create(channel: channel)
      rule4 = DiscourseChatIntegration::Rule.create(channel: channel2)
      rule5 = DiscourseChatIntegration::Rule.create(channel: channel3)

      expect(DiscourseChatIntegration::Rule.all.length).to eq(5)

      expect(DiscourseChatIntegration::Rule.with_channel(channel).length).to eq(3)
      expect(DiscourseChatIntegration::Rule.with_channel(channel2).length).to eq(1)
    end

    it "can be filtered by category" do
      rule2 = DiscourseChatIntegration::Rule.create(channel: channel, category_id: category.id)
      rule3 = DiscourseChatIntegration::Rule.create(channel: channel, category_id: nil)

      expect(DiscourseChatIntegration::Rule.all.length).to eq(3)

      expect(DiscourseChatIntegration::Rule.with_category_id(category.id).length).to eq(2)
      expect(DiscourseChatIntegration::Rule.with_category_id(nil).length).to eq(1)
    end

    it "can be filtered by group" do
      group1 = Fabricate(:group)
      group2 = Fabricate(:group)
      rule2 =
        DiscourseChatIntegration::Rule.create!(
          channel: channel,
          type: "group_message",
          group_id: group1.id,
        )
      rule3 =
        DiscourseChatIntegration::Rule.create!(
          channel: channel,
          type: "group_message",
          group_id: group2.id,
        )

      expect(DiscourseChatIntegration::Rule.all.length).to eq(3)

      expect(DiscourseChatIntegration::Rule.with_category_id(category.id).length).to eq(1)
      expect(DiscourseChatIntegration::Rule.with_group_ids([group1.id, group2.id]).length).to eq(2)
      expect(DiscourseChatIntegration::Rule.with_group_ids([group1.id]).length).to eq(1)
      expect(DiscourseChatIntegration::Rule.with_group_ids([group2.id]).length).to eq(1)
    end

    it "can be filtered by type" do
      group1 = Fabricate(:group)

      rule2 =
        DiscourseChatIntegration::Rule.create!(
          channel: channel,
          type: "group_message",
          group_id: group1.id,
        )
      rule3 =
        DiscourseChatIntegration::Rule.create!(
          channel: channel,
          type: "group_mention",
          group_id: group1.id,
        )

      expect(DiscourseChatIntegration::Rule.all.length).to eq(3)

      expect(DiscourseChatIntegration::Rule.with_type("group_message").length).to eq(1)
      expect(DiscourseChatIntegration::Rule.with_type("group_mention").length).to eq(1)
      expect(DiscourseChatIntegration::Rule.with_type("normal").length).to eq(1)
    end

    it "can be sorted by precedence" do
      rule2 = DiscourseChatIntegration::Rule.create(channel: channel, filter: "mute")
      rule3 = DiscourseChatIntegration::Rule.create(channel: channel, filter: "follow")
      rule4 = DiscourseChatIntegration::Rule.create(channel: channel, filter: "thread")
      rule5 = DiscourseChatIntegration::Rule.create(channel: channel, filter: "mute")

      expect(DiscourseChatIntegration::Rule.all.length).to eq(5)

      expect(DiscourseChatIntegration::Rule.all.order_by_precedence.map(&:filter)).to eq(
        %w[mute mute thread watch follow],
      )
    end
  end

  describe "validations" do
    let(:rule) do
      DiscourseChatIntegration::Rule.create(
        filter: "watch",
        channel: channel,
        category_id: category.id,
      )
    end

    it "validates channel correctly" do
      expect(rule.valid?).to eq(true)
      rule.channel_id = "blahblahblah"
      expect(rule.valid?).to eq(false)
      rule.channel_id = -1
      expect(rule.valid?).to eq(false)
    end

    it "doesn't allow both category and group to be set" do
      expect(rule.valid?).to eq(true)
      rule.group_id = group.id
      expect(rule.valid?).to eq(false)
      rule.category_id = nil
      rule.type = "group_message"
      expect(rule.valid?).to eq(true)
    end

    it "validates group correctly" do
      rule.category_id = nil
      rule.group_id = group.id
      rule.type = "group_message"
      expect(rule.valid?).to eq(true)
      rule.group_id = -99
      expect(rule.valid?).to eq(false)
    end

    it "validates category correctly" do
      expect(rule.valid?).to eq(true)
      rule.category_id = -99
      expect(rule.valid?).to eq(false)
    end

    it "validates filter correctly" do
      expect(rule.valid?).to eq(true)
      rule.filter = "thread"
      expect(rule.valid?).to eq(true)
      rule.filter = "follow"
      expect(rule.valid?).to eq(true)
      rule.filter = "mute"
      expect(rule.valid?).to eq(true)
      rule.filter = ""
      expect(rule.valid?).to eq(false)
      rule.filter = "somerandomstring"
      expect(rule.valid?).to eq(false)
    end

    it "validates tags correctly" do
      expect(rule.valid?).to eq(true)
      rule.tags = []
      expect(rule.valid?).to eq(true)
      rule.tags = [tag1.name]
      expect(rule.valid?).to eq(true)
      rule.tags = [tag1.name, "blah"]
      expect(rule.valid?).to eq(false)
    end

    it "doesn't allow save when invalid" do
      expect(rule.valid?).to eq(true)
      rule.filter = "somerandomfilter"
      expect(rule.valid?).to eq(false)
      expect(rule.save).to eq(false)
    end
  end
end
