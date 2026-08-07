# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ChatMessageCreated::V1 do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:other_channel, :chat_channel)
  fab!(:direct_message_channel, :direct_message_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user) }
  fab!(:direct_message) do
    Fabricate(:chat_message, chat_channel: direct_message_channel, user: user)
  end

  before { SiteSetting.chat_enabled = true }

  it "returns the correct identifier" do
    expect(described_class.identifier).to eq("trigger:chat_message_created")
  end

  describe ".load_options_context" do
    fab!(:other_channel) { Fabricate(:chat_channel, name: "Announcements") }
    fab!(:closed_channel) { Fabricate(:chat_channel, name: "Closed", status: :closed) }
    fab!(:dm_channel, :direct_message_channel)

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "chat_channels",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns open public channels with id and name" do
      ids = load_options.map { |option| option[:id] }

      expect(ids).to include(channel.id, other_channel.id)
      expect(ids).not_to include(closed_channel.id, dm_channel.id)
    end

    it "filters channels by the filter term" do
      expect(load_options(filter: "announce")).to contain_exactly(
        { id: other_channel.id, name: other_channel.name },
      )
    end
  end

  it "serializes the message, channel, and user", :aggregate_failures do
    output = described_class.new(message, channel, user).output

    expect(output[:message]).to include(
      id: message.id,
      message: message.message,
      chat_channel_id: channel.id,
    )
    expect(output[:channel]).to include(id: channel.id, slug: channel.slug)
    expect(output[:user]).to include(
      id: user.id,
      username: user.username,
      avatar_template: user.avatar_template,
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "matches nodes with no channel filter or the same channel" do
    trigger = described_class.new(message, channel, user)

    expect(trigger.matches?(trigger_context({}))).to eq(true)
    expect(trigger.matches?(trigger_context("channel_id" => channel.id.to_s))).to eq(true)
    expect(trigger.matches?(trigger_context("channel_id" => other_channel.id.to_s))).to eq(false)
  end

  it "does not match direct message channels" do
    trigger = described_class.new(direct_message, direct_message_channel, user)

    expect(trigger.matches?(trigger_context({}))).to eq(false)
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
