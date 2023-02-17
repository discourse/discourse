# frozen_string_literal: true

class Chat::ChatMessageMentions
  def initialize(message)
    @message = message

    mentions = parse_mentions(message)
    group_mentions = parse_group_mentions(message)

    @has_global_mention = mentions.include?("@all")
    @has_here_mention = mentions.include?("@here")
    @parsed_direct_mentions = normalize(mentions)
    @parsed_group_mentions = normalize(group_mentions)
  end

  attr_accessor :has_global_mention,
                :has_here_mention,
                :parsed_direct_mentions,
                :parsed_group_mentions

  def global_mentions
    return User.none unless @has_global_mention
    channel_members.where.not(username_lower: @parsed_direct_mentions)
  end

  def direct_mentions
    chat_users.where(username_lower: @parsed_direct_mentions)
  end

  def group_mentions
    chat_users.includes(:groups).joins(:groups).where(groups: mentionable_groups)
  end

  def here_mentions
    return User.none unless @has_here_mention

    channel_members
      .where("last_seen_at > ?", 5.minutes.ago)
      .where.not(username_lower: @parsed_direct_mentions)
  end

  def mentionable_groups
    @mentionable_groups ||=
      Group.mentionable(@message.user, include_public: false).where(id: visible_groups.map(&:id))
  end

  def visible_groups
    @visible_groups ||=
      Group.where("LOWER(name) IN (?)", @parsed_group_mentions).visible_groups(@message.user)
  end

  private

  def channel_members
    chat_users.where(
      user_chat_channel_memberships: {
        following: true,
        chat_channel_id: @message.chat_channel.id,
      },
    )
  end

  def chat_users
    User
      .includes(:user_chat_channel_memberships, :group_users)
      .distinct
      .joins("LEFT OUTER JOIN user_chat_channel_memberships uccm ON uccm.user_id = users.id")
      .joins(:user_option)
      .real
      .not_suspended
      .where(user_options: { chat_enabled: true })
      .where.not(username_lower: @message.user.username.downcase)
  end

  def parse_mentions(message)
    Nokogiri::HTML5.fragment(message.cooked).css(".mention").map(&:text)
  end

  def parse_group_mentions(message)
    Nokogiri::HTML5.fragment(message.cooked).css(".mention-group").map(&:text)
  end

  def normalize(mentions)
    mentions.reduce([]) do |memo, mention|
      %w[@here @all].include?(mention.downcase) ? memo : (memo << mention[1..-1].downcase)
    end
  end
end
