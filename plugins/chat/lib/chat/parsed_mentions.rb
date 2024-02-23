# frozen_string_literal: true

module Chat
  class ParsedMentions
    def initialize(message)
      @message = message
      @channel = message.chat_channel
      @sender = message.user

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
      @channel.members
    end

    def here_mentions
      return User.none unless @has_here_mention
      @channel.members_here
    end

    def direct_mentions
      User.where(username_lower: @parsed_direct_mentions)
    end

    def group_mentions
      users_reached_by_group_mentions_info.map { |info| info[:user] }
    end

    def has_mass_mention
      @has_global_mention || @has_here_mention
    end

    def groups_to_mention
      @groups_to_mention ||=
        mentionable_groups.where(
          "user_count <= ?",
          SiteSetting.max_users_notified_per_group_mention,
        )
    end

    def groups_with_disabled_mentions
      @groups_with_disabled_mentions ||= (visible_groups - mentionable_groups).to_a
    end

    def groups_with_too_many_members
      @groups_with_too_many_members ||=
        mentionable_groups.where(
          "user_count > ?",
          SiteSetting.max_users_notified_per_group_mention,
        ).to_a
    end

    def visible_groups
      @visible_groups ||=
        Group.where("LOWER(name) IN (?)", @parsed_group_mentions).visible_groups(@sender).to_a
    end

    def users_who_can_join_channel
      @users_who_can_join_channel ||=
        all_users_reached_by_mentions.filter do |user|
          user.guardian.can_join_chat_channel?(@channel)
        end
    end

    def users_who_cannot_join_channel
      @users_who_cannot_join_channel ||=
        all_users_reached_by_mentions.filter do |user|
          !user.guardian.can_join_chat_channel?(@channel)
        end
    end

    def users_to_send_invitation_to_channel
      @users_to_send_invitation_to_channel ||=
        users_who_can_join_channel.filter do |user|
          !user.following?(@channel) && !user.doesnt_want_to_hear_from(@sender)
        end
    end

    def all_users_reached_by_mentions_info
      @all_users_reached_by_mentions_info ||=
        begin
          users = users_reached_by_direct_mentions_info
          users.concat(users_reached_by_group_mentions_info)
          users.concat(users_reached_by_here_mentions_info)
          users.concat(users_reached_by_global_mentions_info)
          users
        end
    end

    private

    def users_reached_by_here_mentions_info
      here_mentions.to_a.map { |info| { user: info, type: "Chat::HereMention" } }
    end

    def users_reached_by_global_mentions_info
      global_mentions.to_a.map { |user| { user: user, type: "Chat::AllMention" } }
    end

    def users_reached_by_direct_mentions_info
      direct_mentions.to_a.map do |user|
        { user: user, type: "Chat::UserMention", target_id: user.id }
      end
    end

    def all_users_reached_by_mentions
      @all_users_reached_by_mentions ||=
        begin
          users = direct_mentions.to_a
          users.concat(group_mentions.to_a)
          users.concat(here_mentions.to_a)
          users.concat(global_mentions.to_a)
          users
        end
    end

    def users_reached_by_group_mentions_info
      group_ids = groups_to_mention.pluck(:id)
      group_users = GroupUser.where(group_id: group_ids).pluck(:user_id, :group_id).to_h

      chat_users
        .where(id: group_users.keys)
        .where.not(username_lower: @sender.username)
        .map { |user| { user: user, target_id: group_users[user.id], type: "Chat::GroupMention" } }
    end

    def chat_users
      User.distinct.includes(:user_option).real.where(user_options: { chat_enabled: true })
    end

    def mentionable_groups
      @mentionable_groups ||=
        Group.mentionable(@sender, include_public: false).where(id: visible_groups.map(&:id))
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
