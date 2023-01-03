# frozen_string_literal: true

require "rails_helper"

describe Chat::ChatMessageReactor do
  fab!(:reacting_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:reactor) { described_class.new(reacting_user, channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, user: reacting_user) }
  let(:subject) { described_class.new(reacting_user, channel) }

  it 'calls guardian ensure_can_join_chat_channel!' do
    Guardian.any_instance.expects(:ensure_can_join_chat_channel!).once
    subject.react!(message_id: message_1.id, react_action: :add, emoji: ":+1:")
  end

  it "raises an error if the user cannot see the channel" do
    channel.update!(chatable: Fabricate(:private_category, group: Group[:staff]))
    expect {
      subject.react!(message_id: message_1.id, react_action: :add, emoji: ":+1:")
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "raises an error if the user cannot react" do
    SpamRule::AutoSilence.new(reacting_user).silence_user
    expect {
      subject.react!(message_id: message_1.id, react_action: :add, emoji: ":+1:")
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "raises an error if the channel status is not open" do
    channel.update!(status: ChatChannel.statuses[:archived])
    expect {
      subject.react!(message_id: message_1.id, react_action: :add, emoji: ":+1:")
    }.to raise_error(Discourse::InvalidAccess)
    channel.update!(status: ChatChannel.statuses[:open])
    expect {
      subject.react!(message_id: message_1.id, react_action: :add, emoji: ":+1:")
    }.to change(ChatMessageReaction, :count).by(1)
  end

  it "raises an error if the reaction is not valid" do
    expect {
      reactor.react!(message_id: message_1.id, react_action: :foo, emoji: ":+1:")
    }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error if the emoji does not exist" do
    expect {
      reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":woohoo:")
    }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error if the message is not found" do
    expect {
      reactor.react!(message_id: -999, react_action: :add, emoji: ":woohoo:")
    }.to raise_error(Discourse::InvalidParameters)
  end

  context "when max reactions has been reached" do
    before do
      emojis = Emoji.all.slice(0, Chat::ChatMessageReactor::MAX_REACTIONS_LIMIT)
      emojis.each do |emoji|
        ChatMessageReaction.create!(
          chat_message: message_1,
          user: reacting_user,
          emoji: ":#{emoji.name}:",
        )
      end
    end

    it "adding a reaction raises an error" do
      expect {
        reactor.react!(
          message_id: message_1.id,
          react_action: :add,
          emoji: ":#{Emoji.all.last.name}:",
        )
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "removing a reaction works" do
      expect {
        reactor.react!(
          message_id: message_1.id,
          react_action: :add,
          emoji: ":#{Emoji.all.first.name}:",
        )
      }.to_not raise_error
    end
  end

  it "creates a membership when not present" do
    expect {
      reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":heart:")
    }.to change(UserChatChannelMembership, :count).by(1)
  end

  it "doesn’t create a membership when present" do
    UserChatChannelMembership.create!(user: reacting_user, chat_channel: channel, following: true)

    expect {
      reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":heart:")
    }.not_to change(UserChatChannelMembership, :count)
  end

  it "can add a reaction" do
    expect {
      reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":heart:")
    }.to change(ChatMessageReaction, :count).by(1)
  end

  it "doesn’t duplicate reactions" do
    ChatMessageReaction.create!(chat_message: message_1, user: reacting_user, emoji: ":heart:")

    expect {
      reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":heart:")
    }.not_to change(ChatMessageReaction, :count)
  end

  it "can remove an existing reaction" do
    ChatMessageReaction.create!(chat_message: message_1, user: reacting_user, emoji: ":heart:")

    expect {
      reactor.react!(message_id: message_1.id, react_action: :remove, emoji: ":heart:")
    }.to change(ChatMessageReaction, :count).by(-1)
  end

  it "does nothing when removing if no reaction found" do
    expect {
      reactor.react!(message_id: message_1.id, react_action: :remove, emoji: ":heart:")
    }.not_to change(ChatMessageReaction, :count)
  end

  it "publishes the reaction" do
    ChatPublisher.expects(:publish_reaction!).once

    reactor.react!(message_id: message_1.id, react_action: :add, emoji: ":heart:")
  end
end
