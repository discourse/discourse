# frozen_string_literal: true

require "rails_helper"
require_relative "../dummy_provider"

RSpec.describe DiscourseChatIntegration::Channel do
  include_context "with dummy provider"
  include_context "with validated dummy provider"

  it "should save and load successfully" do
    expect(DiscourseChatIntegration::Channel.all.length).to eq(0)

    chan = DiscourseChatIntegration::Channel.create(provider: "dummy")

    expect(DiscourseChatIntegration::Channel.all.length).to eq(1)

    loadedChan = DiscourseChatIntegration::Channel.find(chan.id)

    expect(loadedChan.provider).to eq("dummy")
  end

  it "should edit successfully" do
    channel = DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "hello" })
    expect(channel.valid?).to eq(true)
    channel.save!
  end

  it "can be filtered by provider" do
    channel1 = DiscourseChatIntegration::Channel.create!(provider: "dummy")
    channel2 = DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "blah" })
    channel3 = DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "blah2" })

    expect(DiscourseChatIntegration::Channel.all.length).to eq(3)

    expect(DiscourseChatIntegration::Channel.with_provider("dummy2").length).to eq(2)
    expect(DiscourseChatIntegration::Channel.with_provider("dummy").length).to eq(1)
  end

  it "can be filtered by data value" do
    channel2 = DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "foo" })
    channel3 = DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "blah" })

    expect(DiscourseChatIntegration::Channel.all.length).to eq(2)

    for_provider = DiscourseChatIntegration::Channel.with_provider("dummy2")
    expect(for_provider.length).to eq(2)

    expect(
      DiscourseChatIntegration::Channel
        .with_provider("dummy2")
        .with_data_value("val", "blah")
        .length,
    ).to eq(1)
  end

  it "can find its own rules" do
    channel = DiscourseChatIntegration::Channel.create(provider: "dummy")
    expect(channel.rules.size).to eq(0)
    DiscourseChatIntegration::Rule.create(channel: channel)
    DiscourseChatIntegration::Rule.create(channel: channel)
    expect(channel.rules.size).to eq(2)
  end

  it "destroys its rules on destroy" do
    channel = DiscourseChatIntegration::Channel.create(provider: "dummy")
    expect(channel.rules.size).to eq(0)
    rule1 = DiscourseChatIntegration::Rule.create(channel: channel)
    rule2 = DiscourseChatIntegration::Rule.create(channel: channel)

    expect(DiscourseChatIntegration::Rule.with_channel(channel).exists?).to eq(true)
    channel.destroy()
    expect(DiscourseChatIntegration::Rule.with_channel(channel).exists?).to eq(false)
  end

  describe "validations" do
    it "validates provider correctly" do
      channel = DiscourseChatIntegration::Channel.create!(provider: "dummy")
      expect(channel.valid?).to eq(true)
      channel.provider = "somerandomprovider"
      expect(channel.valid?).to eq(false)
    end

    it "succeeds with valid data" do
      channel2 = DiscourseChatIntegration::Channel.new(provider: "dummy2", data: { val: "hello" })
      expect(channel2.valid?).to eq(true)
    end

    it "disallows invalid data" do
      channel2 = DiscourseChatIntegration::Channel.new(provider: "dummy2", data: { val: "  " })
      expect(channel2.valid?).to eq(false)
    end

    it "disallows unknown keys" do
      channel2 =
        DiscourseChatIntegration::Channel.new(
          provider: "dummy2",
          data: {
            val: "hello",
            unknown: "world",
          },
        )
      expect(channel2.valid?).to eq(false)
    end

    it "requires all keys" do
      channel2 = DiscourseChatIntegration::Channel.new(provider: "dummy2", data: {})
      expect(channel2.valid?).to eq(false)
    end

    it "disallows duplicate channels" do
      channel1 =
        DiscourseChatIntegration::Channel.create(provider: "dummy2", data: { val: "hello" })
      channel2 = DiscourseChatIntegration::Channel.new(provider: "dummy2", data: { val: "hello" })
      expect(channel2.valid?).to eq(false)
      channel2.data[:val] = "hello2"
      expect(channel2.valid?).to eq(true)
    end
  end
end
