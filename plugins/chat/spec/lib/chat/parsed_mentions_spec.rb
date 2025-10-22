# frozen_string_literal: true

RSpec.describe Chat::ParsedMentions do
  fab!(:channel_member_1, :user)
  fab!(:channel_member_2, :user)
  fab!(:channel_member_3, :user)
  fab!(:not_a_channel_member, :user)
  fab!(:chat_channel)

  def message_quote_with_mentions(mentions)
    <<~MARKDOWN
    [chat quote="jan;100;2023-10-10T13:00:00Z"]
    message mentioning #{mentions.map { |m| "@#{m}" }.join(" ")}
    [/chat]
    MARKDOWN
  end

  def post_quote_with_mentions(mentions)
    <<~MARKDOWN
    [quote="jan, post:1, topic:10"]
    message mentioning #{mentions.map { |m| "@#{m}" }.join(" ")}
    [/quote]
    MARKDOWN
  end

  before do
    chat_channel.add(channel_member_1)
    chat_channel.add(channel_member_2)
    chat_channel.add(channel_member_3)
  end

  describe "#global_mentions" do
    it "returns all members of the channel" do
      message = create_message("mentioning @all")

      mentions = described_class.new(message)
      result = mentions.global_mentions.pluck(:username)

      expect(result).to contain_exactly(
        channel_member_1.username,
        channel_member_2.username,
        channel_member_3.username,
      )
    end

    it "doesn't include users that were also mentioned directly" do
      message = create_message("mentioning @all and @#{channel_member_1.username}")

      mentions = described_class.new(message)
      result = mentions.global_mentions.pluck(:username)

      expect(result).to contain_exactly(channel_member_2.username, channel_member_3.username)
    end

    it "returns an empty list if there are no global mentions" do
      message = create_message("not mentioning anybody")

      mentions = described_class.new(message)
      result = mentions.global_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a message with global mentions" do
      message = create_message(message_quote_with_mentions(["all"]))

      mentions = described_class.new(message)
      result = mentions.global_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a post with global mentions" do
      message = create_message(post_quote_with_mentions(["all"]))

      mentions = described_class.new(message)
      result = mentions.global_mentions.pluck(:username)

      expect(result).to be_empty
    end
  end

  describe "#here_mentions" do
    before do
      freeze_time
      channel_member_1.update(last_seen_at: 2.minutes.ago)
      channel_member_2.update(last_seen_at: 2.minutes.ago)
      channel_member_3.update(last_seen_at: 5.minutes.ago)
    end

    it "returns all members of the channel who were online in the last 5 minutes" do
      message = create_message("mentioning @here")

      mentions = described_class.new(message)
      result = mentions.here_mentions.pluck(:username)

      expect(result).to contain_exactly(channel_member_1.username, channel_member_2.username)
    end

    it "doesn't include users that were also mentioned directly" do
      message = create_message("mentioning @here and @#{channel_member_1.username}")

      mentions = described_class.new(message)
      result = mentions.here_mentions.pluck(:username)

      expect(result).to contain_exactly(channel_member_2.username)
    end

    it "returns an empty list if there are no here mentions" do
      message = create_message("not mentioning anybody")

      mentions = described_class.new(message)
      result = mentions.here_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a message with here mentions" do
      message = create_message(message_quote_with_mentions(["here"]))

      mentions = described_class.new(message)
      result = mentions.here_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a post with here mentions" do
      message = create_message(post_quote_with_mentions(["here"]))

      mentions = described_class.new(message)
      result = mentions.here_mentions.pluck(:username)

      expect(result).to be_empty
    end
  end

  describe "#direct_mentions" do
    it "returns users who were mentioned directly" do
      message =
        create_message("mentioning @#{channel_member_1.username} and @#{channel_member_2.username}")

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to contain_exactly(channel_member_1.username, channel_member_2.username)
    end

    it "returns bots who were mentioned directly" do
      message = create_message("mentioning @system")

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to contain_exactly(Discourse.system_user.username)
    end

    it "returns a user when self-mentioning" do
      message = create_message("Hey @#{channel_member_1.username}", user: channel_member_1)

      mentions = described_class.new(message)

      result = mentions.direct_mentions.pluck(:username)
      expect(result).to contain_exactly(channel_member_1.username)
    end

    it "returns a mentioned user even if he's not a member of the channel" do
      message = create_message("mentioning @#{not_a_channel_member.username}")

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to contain_exactly(not_a_channel_member.username)
    end

    it "returns an empty list if no one was mentioned directly" do
      message = create_message("not mentioning anybody")

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a message with mentioned users" do
      message =
        create_message(
          message_quote_with_mentions([channel_member_1.username, channel_member_2.username]),
        )

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a post with mentioned users" do
      message =
        create_message(
          post_quote_with_mentions([channel_member_1.username, channel_member_2.username]),
        )

      mentions = described_class.new(message)
      result = mentions.direct_mentions.pluck(:username)

      expect(result).to be_empty
    end
  end

  describe "#group_mentions" do
    fab!(:group1) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
    fab!(:group_member_1) { Fabricate(:user, group_ids: [group1.id]) }
    fab!(:group_member_2) { Fabricate(:user, group_ids: [group1.id]) }
    fab!(:group_member_3) { Fabricate(:user, group_ids: [group1.id]) }

    before do
      chat_channel.add(group_member_1)
      chat_channel.add(group_member_2)
    end

    it "returns members of a mentioned group even if some of them is not members of the channel" do
      message = create_message("mentioning @#{group1.name}")

      mentions = described_class.new(message)
      result = mentions.group_mentions.pluck(:username)

      expect(result).to contain_exactly(
        group_member_1.username,
        group_member_2.username,
        group_member_3.username,
      )
    end

    it "returns an empty list if no group was mentioned" do
      message = create_message("not mentioning anyone")

      mentions = described_class.new(message)
      result = mentions.group_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when mentioning an unmentionable group" do
      group1.mentionable_level = Group::ALIAS_LEVELS[:nobody]
      group1.save!
      message = create_message("mentioning @#{group1.name}")

      mentions = described_class.new(message)
      result = mentions.group_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a message with a mentioned group" do
      message = create_message(message_quote_with_mentions([group1.name]))

      mentions = described_class.new(message)
      result = mentions.group_mentions.pluck(:username)

      expect(result).to be_empty
    end

    it "returns an empty list when quoting a post with a mentioned group" do
      message = create_message(post_quote_with_mentions([group1.name]))

      mentions = described_class.new(message)
      result = mentions.group_mentions.pluck(:username)

      expect(result).to be_empty
    end
  end

  def create_message(text, **extra_args)
    Fabricate(:chat_message, chat_channel: chat_channel, message: text, **extra_args)
  end
end
