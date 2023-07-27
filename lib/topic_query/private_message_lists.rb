# frozen_string_literal: true

class TopicQuery
  module PrivateMessageLists
    def list_private_messages(user, &blk)
      list = user_personal_private_messages(user)
      list = not_archived(list, user)
      list = have_posts_from_others(list, user)

      create_list(:private_messages, {}, list, &blk)
    end

    def list_private_messages_direct_and_groups(user, groups_messages_notification_level: nil, &blk)
      list =
        user_personal_and_groups_private_messages(
          user,
          groups_messages_notification_level: groups_messages_notification_level,
        )

      list = not_archived(list, user)
      list = not_archived_in_groups(list)
      list = have_posts_from_others(list, user)

      create_list(:private_messages, {}, list, &blk)
    end

    def list_private_messages_archive(user)
      list = user_personal_private_messages(user)

      list =
        list.joins(:user_archived_messages).where("user_archived_messages.user_id = ?", user.id)

      create_list(:private_messages, {}, list)
    end

    def list_private_messages_sent(user)
      list = user_personal_private_messages(user)

      list = list.where(<<~SQL, user.id)
      EXISTS (
        SELECT 1 FROM posts
        WHERE posts.topic_id = topics.id AND posts.user_id = ?
      )
      SQL

      list = not_archived(list, user)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_new(user, type = :user)
      list = filter_private_message_new(user, type)
      list = TopicQuery.remove_muted_tags(list, user, skip_categories: true)
      list = remove_dismissed(list, user)

      create_list(:private_messages, {}, list)
    end

    def list_private_messages_unread(user, type = :user)
      list = filter_private_messages_unread(user, type)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_group(user)
      list = user_groups_private_messages(user)

      list = list.joins(<<~SQL)
      LEFT JOIN group_archived_messages gm
      ON gm.topic_id = topics.id AND gm.group_id = #{group.id.to_i}
      SQL

      list = list.where("gm.id IS NULL")
      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state, group: group }, list)
    end

    def list_private_messages_group_archive(user)
      list = user_groups_private_messages(user)

      list = list.joins(<<~SQL)
      INNER JOIN group_archived_messages gm
      ON gm.topic_id = topics.id AND gm.group_id = #{group.id.to_i}
      SQL

      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state, group: group }, list)
    end

    def list_private_messages_group_new(user)
      list = filter_private_message_new(user, :group)
      list = remove_dismissed(list, user)
      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state, group: group }, list)
    end

    def list_private_messages_group_unread(user)
      list = filter_private_messages_unread(user, :group)
      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state, group: group }, list)
    end

    def list_private_messages_warnings(user)
      list = user_personal_private_messages(user)
      list = list.where("topics.subtype = ?", TopicSubtype.moderator_warning)
      # Exclude official warnings that the user created, instead of received
      list = list.where("topics.user_id <> ?", user.id)
      create_list(:private_messages, {}, list)
    end

    def private_messages_for(user, type)
      if type == :group
        user_groups_private_messages(user)
      elsif type == :user
        user_personal_private_messages(user)
      elsif type == :all
        user_personal_and_groups_private_messages(user)
      end
    end

    def list_private_messages_tag(user)
      list = user_personal_and_groups_private_messages(user)

      list =
        list.joins(
          "JOIN topic_tags tt ON tt.topic_id = topics.id
                        JOIN tags t ON t.id = tt.tag_id AND t.name = '#{@options[:tags][0]}'",
        )

      create_list(:private_messages, {}, list)
    end

    def filter_private_messages_unread(user, type)
      list = TopicQuery.unread_filter(private_messages_for(user, type), whisperer: user.whisperer?)

      first_unread_pm_at =
        case type
        when :user
          user_first_unread_pm_at(user)
        when :group
          GroupUser.where(user: user, group: group).pick(:first_unread_pm_at)
        else
          user_first_unread_pm_at = user_first_unread_pm_at(user)

          group_first_unread_pm_at = GroupUser.where(user: user).minimum(:first_unread_pm_at)

          [user_first_unread_pm_at, group_first_unread_pm_at].compact.min
        end

      list = list.where("topics.updated_at >= ?", first_unread_pm_at) if first_unread_pm_at

      list
    end

    def filter_private_message_new(user, type)
      TopicQuery.new_filter(
        private_messages_for(user, type),
        treat_as_new_topic_start_date: user.user_option.treat_as_new_topic_start_date,
      )
    end

    private

    def append_read_state(list, group)
      group_id = group.id
      return list if group_id.nil?

      selected_values = list.select_values.empty? ? ["topics.*"] : list.select_values
      selected_values << "COALESCE(tg.last_read_post_number, 0) AS last_read_post_number"

      list.joins(
        "LEFT OUTER JOIN topic_groups tg ON topics.id = tg.topic_id AND tg.group_id = #{group_id}",
      ).select(*selected_values)
    end

    def filter_archived(list, user, archived: true)
      # Executing an extra query instead of a sub-query because it is more
      # efficient for the PG planner. Caution should be used when changing the
      # query here as it can easily lead to an inefficient query.
      group_ids = group_with_messages_ids(user)

      if group_ids.present?
        list = list.joins(<<~SQL)
          LEFT JOIN group_archived_messages gm
            ON gm.topic_id = topics.id
            AND gm.group_id IN (#{group_ids.join(",")})
          LEFT JOIN user_archived_messages um
            ON um.user_id = #{user.id.to_i}
            AND um.topic_id = topics.id
        SQL

        if archived
          list.where("um.user_id IS NOT NULL OR gm.topic_id IS NOT NULL")
        else
          list.where("um.user_id IS NULL AND gm.topic_id IS NULL")
        end
      else
        list = list.joins(<<~SQL)
          LEFT JOIN user_archived_messages um
          ON um.user_id = #{user.id.to_i}
          AND um.topic_id = topics.id
        SQL

        list.where("um.user_id IS #{archived ? "NOT NULL" : "NULL"}")
      end
    end

    def not_archived(list, user)
      list.joins(
        "LEFT JOIN user_archived_messages um
                         ON um.user_id = #{user.id.to_i} AND um.topic_id = topics.id",
      ).where("um.user_id IS NULL")
    end

    def not_archived_in_groups(list)
      list.left_joins(:group_archived_messages).where(group_archived_messages: { id: nil })
    end

    def have_posts_from_others(list, user)
      list.where(<<~SQL, user.id.to_i)
        NOT (
          topics.participant_count = 1
          AND topics.user_id = ?
          AND topics.moderator_posts_count = 0
        )
      SQL
    end

    def group
      @group ||=
        begin
          Group.where("name ilike ?", @options[:group_name]).select(:id, :publish_read_state).first
        end
    end

    def user_first_unread_pm_at(user)
      UserStat.where(user: user).pick(:first_unread_pm_at)
    end

    def group_with_messages_ids(user)
      @group_with_messages_ids ||= {}

      if ids = @group_with_messages_ids[user.id]
        return ids
      end

      @group_with_messages_ids[user.id] = user.groups.where(has_messages: true).pluck(:id)
    end

    private

    def private_messages_default_scope(user)
      options = @options
      options.reverse_merge!(per_page: per_page_setting)

      result =
        Topic
          .private_messages
          .includes(:allowed_users)
          .includes(:allowed_groups)
          .joins(
            "LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{user.id.to_i})",
          )
          .order("topics.bumped_at DESC")

      result = result.includes(:tags) if SiteSetting.tagging_enabled
      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?

      if options[:page]
        offset = options[:page].to_i * options[:per_page]
        result = result.offset(offset) if offset > 0
      end

      result
    end

    def user_groups_private_messages(user)
      result = private_messages_default_scope(user)

      result =
        result.joins(
          "INNER JOIN topic_allowed_groups tag ON tag.topic_id = topics.id AND tag.group_id IN (SELECT id FROM groups WHERE LOWER(name) = '#{PG::Connection.escape_string(@options[:group_name].downcase)}')",
        )

      unless user.admin?
        result =
          result.joins(
            "INNER JOIN group_users gu ON gu.group_id = tag.group_id AND gu.user_id = #{user.id.to_i}",
          )
      end

      result
    end

    def user_personal_private_messages(user)
      result = private_messages_default_scope(user)

      result.where(
        "topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)",
        user.id.to_i,
      )
    end

    def user_personal_and_groups_private_messages(user, groups_messages_notification_level: nil)
      result = private_messages_default_scope(user)
      group_ids = group_with_messages_ids(user)

      topic_allowed_groups_scope =
        if groups_messages_notification_level.present? &&
             notification_level =
               NotificationLevels.topic_levels[groups_messages_notification_level]
          <<~SQL
          SELECT topic_allowed_groups.topic_id
          FROM topic_allowed_groups
          INNER JOIN topic_users ON topic_users.topic_id = topic_allowed_groups.topic_id AND topic_users.user_id = :user_id
          WHERE group_id IN (:group_ids)
          AND topic_users.notification_level >= #{notification_level.to_i}
          SQL
        else
          "SELECT topic_id FROM topic_allowed_groups WHERE group_id IN (:group_ids)"
        end

      result =
        if group_ids.present?
          result.where(<<~SQL, user_id: user.id.to_i, group_ids: group_ids)
          topics.id IN (
            SELECT topic_id
            FROM topic_allowed_users
            WHERE user_id = :user_id
            UNION ALL
            #{topic_allowed_groups_scope}
          )
          SQL
        else
          result.joins(<<~SQL)
          INNER JOIN topic_allowed_users tau
          ON tau.topic_id = topics.id
          AND tau.user_id = #{user.id.to_i}
          SQL
        end
    end
  end
end
