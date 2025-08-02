# frozen_string_literal: true

module Chat
  class ParsedMentions
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

    def count
      @count ||=
        begin
          result = @parsed_direct_mentions.length + @parsed_group_mentions.length
          result += 1 if @has_global_mention
          result += 1 if @has_here_mention
          result
        end
    end

    def global_mentions
      return User.none unless @has_global_mention
      channel_members.where.not(username_lower: @parsed_direct_mentions)
    end

    def direct_mentions
      chat_users.where(username_lower: @parsed_direct_mentions)
    end

    def group_mentions
      group_ids = groups_to_mention.pluck(:id)
      group_user_ids = GroupUser.where(group_id: group_ids).pluck(:user_id)
      chat_users.where(id: group_user_ids)
    end

    def here_mentions
      return User.none unless @has_here_mention

      channel_members
        .where("last_seen_at > ?", 5.minutes.ago)
        .where.not(username_lower: @parsed_direct_mentions)
    end

    def groups_to_mention
      @groups_to_mention ||=
        mentionable_groups.where(
          "user_count <= ?",
          SiteSetting.max_users_notified_per_group_mention,
        )
    end

    def groups_with_disabled_mentions
      @groups_with_disabled_mentions ||= visible_groups - mentionable_groups
    end

    def groups_with_too_many_members
      @groups_with_too_many_members ||=
        mentionable_groups.where("user_count > ?", SiteSetting.max_users_notified_per_group_mention)
    end

    def visible_groups
      @visible_groups ||=
        Group.where("LOWER(name) IN (?)", @parsed_group_mentions).visible_groups(@message.user)
    end

    private

    def channel_members
      chat_users.includes(:user_chat_channel_memberships).where(
        user_chat_channel_memberships: {
          following: true,
          chat_channel_id: @message.chat_channel.id,
        },
      )
    end

    def chat_users
      User.distinct.joins(:user_option).where(user_options: { chat_enabled: true })
    end

    def mentionable_groups
      @mentionable_groups ||=
        Group.mentionable(@message.user, include_public: false).where(id: visible_groups.map(&:id))
    end

    def parse_mentions(message)
      cooked_stripped(message).css(".mention").map(&:text)
    end

    def parse_group_mentions(message)
      cooked_stripped(message).css(".mention-group").map(&:text)
    end

    def cooked_stripped(message)
      cooked = Nokogiri::HTML5.fragment(message.cooked)
      cooked.css(
        ".chat-transcript .mention, .chat-transcript .mention-group, aside.quote .mention, aside.quote .mention-group",
      ).remove
      cooked
    end

    def normalize(mentions)
      mentions.reduce([]) do |memo, mention|
        %w[@here @all].include?(mention.downcase) ? memo : (memo << mention[1..-1].downcase)
      end
    end
  end
end
