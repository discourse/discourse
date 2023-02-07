# frozen_string_literal: true

module Chat
  class AutoRemoveMembershipEventHandler
    ALLOWED_EVENTS = %i[chat_allowed_groups_changed user_removed_from_group category_updated]

    def initialize(event_type:, event_data:)
      @event_type = event_type
      @event_data = event_data
    end

    def call!
      validate_event!
      handle_event
    end

    private

    def validate_event!
      if !ALLOWED_EVENTS.include?(@event_type)
        raise StandardError.new("Invalid event, allowed events are #{ALLOWED_EVENTS.join(",")}")
      end
    end

    def handle_event
      case @event_type
      when :chat_allowed_groups_changed
        # x = User.real.activated.not_suspended.not_staged.where.not(admin: true, moderator: true)
        # x = DB.query(<<~SQL)
        #   SELECT users.username
        #   FROM users
        #   LEFT JOIN group_users ON group_users.user_id = users.id
        #   WHERE group_users.group_id NOT IN (#{}) OR group_users.id IS NULL
        # SQL
        # any users who are _not_ in these groups
        # and who are _not_staff
        # should be de-stroyed

        new_allowed_groups = @event_data[:new_allowed_groups].to_s.split("|")
        users =
          User
            .real
            .activated
            .not_suspended
            .not_staged
            .where("NOT admin AND NOT moderator")
            .distinct
            .where(
              "users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (#{new_allowed_groups.join(",")})
              )",
            )
            .pluck(:id)
        # .joins("LEFT JOIN group_users ON group_users.user_id = users.id")
        # .where(
        #   "group_users.group_id NOT IN (#{@event_data[:new_allowed_groups].to_s.split("|").join(",")})",
        # )

        UserChatChannelMembership.where(user_id: users).delete_all
      when :user_removed_from_group
        event_user = @event_data[:user].reload

        # if the group the user was removed from is one of the chat allowed groups, check if they are still in any of the other chat allowed groups, otherwise kick

        # get a map of all groups that are allowed to access the channels the user is a member of and their permission level. for channels where the user is
        # not a member of any valid groups anymore, kick
        channel_group_map = DB.query(<<~SQL)
          SELECT chat_channels.id AS channel_id, chat_channels.chatable_id AS category_id, category_groups.group_id, category_groups.permission_type
          FROM chat_channels
          INNER JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'
          INNER JOIN category_groups ON category_groups.category_id = categories.id
        SQL

        channel_ids = channel_group_map.map(&:channel_id).uniq
        user_memberships =
          UserChatChannelMembership.where(chat_channel_id: channel_ids, user: event_user)

        memberships_to_delete = []
        user_memberships.each do |membership|
          channel_group_permissions =
            channel_group_map.select { |cgm| cgm.channel_id == membership.chat_channel_id }

          # if the user is in none of the groups then they need to be kicked out
          if !event_user.in_any_groups?(channel_group_permissions.map(&:group_id))
            memberships_to_delete << membership.id
            next
          end

          # if the user has permission to reply with any of the channel groups,
          # then they are safe
          if channel_group_permissions.any? { |cgm|
               cgm.permission_type < CategoryGroup.permission_types[:readonly]
             }
            next
          end

          memberships_to_delete << membership.id
        end

        UserChatChannelMembership.where(id: memberships_to_delete).delete_all
      when :category_updated
      end
    end
  end
end
