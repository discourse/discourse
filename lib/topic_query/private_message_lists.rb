# frozen_string_literal: true

class TopicQuery
  module PrivateMessageLists
    def list_private_messages_all(user)
      list = private_messages_for(user, :all)
      list = filter_archived(list, user, archived: false)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_all_sent(user)
      list = private_messages_for(user, :all)

      list = list.where(<<~SQL, user.id)
      EXISTS (
        SELECT 1 FROM posts
        WHERE posts.topic_id = topics.id AND posts.user_id = ?
      )
      SQL

      list = filter_archived(list, user, archived: false)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_all_archive(user)
      list = private_messages_for(user, :all)
      list = filter_archived(list, user, archived: true)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_all_new(user)
      list_private_messages_new(user, :all)
    end

    def list_private_messages_all_unread(user)
      list_private_messages_unread(user, :all)
    end

    def list_private_messages(user)
      list = private_messages_for(user, :user)
      list = not_archived(list, user)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_archive(user)
      list = private_messages_for(user, :user)
      list = list.joins(:user_archived_messages).where('user_archived_messages.user_id = ?', user.id)
      create_list(:private_messages, {}, list)
    end

    def list_private_messages_sent(user)
      list = private_messages_for(user, :user)

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
      list = TopicQuery.new_filter(
        private_messages_for(user, type),
        treat_as_new_topic_start_date: user.user_option.treat_as_new_topic_start_date
      )

      list = remove_muted_tags(list, user)

      create_list(:private_messages, {}, list)
    end

    def list_private_messages_unread(user, type = :user)
      list = TopicQuery.unread_filter(
        private_messages_for(user, type),
        staff: user.staff?
      )

      first_unread_pm_at = UserStat
        .where(user_id: user.id)
        .pluck_first(:first_unread_pm_at)

      if first_unread_pm_at
        list = list.where("topics.updated_at >= ?", first_unread_pm_at)
      end

      create_list(:private_messages, {}, list)
    end

    def list_private_messages_group(user)
      list = private_messages_for(user, :group)

      list = list.joins(<<~SQL)
      LEFT JOIN group_archived_messages gm
      ON gm.topic_id = topics.id AND gm.group_id = #{group.id.to_i}
      SQL

      list = list.where("gm.id IS NULL")
      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state }, list)
    end

    def list_private_messages_group_archive(user)
      list = private_messages_for(user, :group)

      list = list.joins(<<~SQL)
      INNER JOIN group_archived_messages gm
      ON gm.topic_id = topics.id AND gm.group_id = #{group.id.to_i}
      SQL

      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state }, list)
    end

    def list_private_messages_group_new(user)
      list = TopicQuery.new_filter(
        private_messages_for(user, :group),
        treat_as_new_topic_start_date: user.user_option.treat_as_new_topic_start_date
      )

      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state }, list)
    end

    def list_private_messages_group_unread(user)
      list = TopicQuery.unread_filter(
        private_messages_for(user, :group),
        staff: user.staff?
      )

      first_unread_pm_at = UserStat
        .where(user_id: user.id)
        .pluck_first(:first_unread_pm_at)

      if first_unread_pm_at
        list = list.where("topics.updated_at >= ?", first_unread_pm_at)
      end

      publish_read_state = !!group.publish_read_state
      list = append_read_state(list, group) if publish_read_state
      create_list(:private_messages, { publish_read_state: publish_read_state }, list)
    end

    def list_private_messages_warnings(user)
      list = private_messages_for(user, :user)
      list = list.where('topics.subtype = ?', TopicSubtype.moderator_warning)
      # Exclude official warnings that the user created, instead of received
      list = list.where('topics.user_id <> ?', user.id)
      create_list(:private_messages, {}, list)
    end

    def private_messages_for(user, type)
      options = @options
      options.reverse_merge!(per_page: per_page_setting)

      result = Topic.includes(:allowed_users)
      result = result.includes(:tags) if tagging_enabled?

      if type == :group
        result = result.joins(
          "INNER JOIN topic_allowed_groups tag ON tag.topic_id = topics.id AND tag.group_id IN (SELECT id FROM groups WHERE LOWER(name) = '#{PG::Connection.escape_string(@options[:group_name].downcase)}')"
        )

        unless user.admin?
          result = result.joins("INNER JOIN group_users gu ON gu.group_id = tag.group_id AND gu.user_id = #{user.id.to_i}")
        end
      elsif type == :user
        result = result.where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = #{user.id.to_i})")
      elsif type == :all
        result = result.where("topics.id IN (
              SELECT topic_id
              FROM topic_allowed_users
              WHERE user_id = #{user.id.to_i}
              UNION ALL
              SELECT topic_id FROM topic_allowed_groups
              WHERE group_id IN (
                SELECT group_id FROM group_users WHERE user_id = #{user.id.to_i}
              )
      )")
      end

      result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{user.id.to_i})")
        .order("topics.bumped_at DESC")
        .private_messages

      if @options[:tag] && tagging_enabled?
        tag_id = Tag.where("lower(name) = ?", @options[:tag]).pluck_first(:id)

        if tag_id
          result = result.joins(<<~SQL)
          INNER JOIN topic_tags
          ON topic_tags.topic_id = topics.id
          AND topic_tags.tag_id = #{tag_id.to_i}
          SQL
        end
      end

      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?

      if options[:page]
        offset = options[:page].to_i * options[:per_page]
        result = result.offset(offset) if offset > 0
      end
      result
    end

    def list_private_messages_tag(user)
      list = private_messages_for(user, :all)
      list = list.joins("JOIN topic_tags tt ON tt.topic_id = topics.id
                        JOIN tags t ON t.id = tt.tag_id AND t.name = '#{@options[:tags][0]}'")
      create_list(:private_messages, {}, list)
    end

    private

    def append_read_state(list, group)
      group_id = group.id
      return list if group_id.nil?

      selected_values = list.select_values.empty? ? ['topics.*'] : list.select_values
      selected_values << "COALESCE(tg.last_read_post_number, 0) AS last_read_post_number"

      list
        .joins("LEFT OUTER JOIN topic_groups tg ON topics.id = tg.topic_id AND tg.group_id = #{group_id}")
        .select(*selected_values)
    end

    def filter_archived(list, user, archived: true)
      list = list.joins(<<~SQL)
      LEFT JOIN group_archived_messages gm ON gm.topic_id = topics.id
      LEFT JOIN user_archived_messages um
        ON um.user_id = #{user.id.to_i}
        AND um.topic_id = topics.id
      SQL

      list =
        if archived
          list.where("um.user_id IS NOT NULL OR gm.topic_id IS NOT NULL")
        else
          list.where("um.user_id IS NULL AND gm.topic_id IS NULL")
        end

      list
    end

    def not_archived(list, user)
      list.joins("LEFT JOIN user_archived_messages um
                         ON um.user_id = #{user.id.to_i} AND um.topic_id = topics.id")
        .where('um.user_id IS NULL')
    end

    def group
      @group ||= begin
        Group
          .where('name ilike ?', @options[:group_name])
          .select(:id, :publish_read_state)
          .first
      end
    end

    def tagging_enabled?
      @guardian.can_tag_pms?
    end
  end
end
