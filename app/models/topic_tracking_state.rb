# frozen_string_literal: true

# This class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using MessageBus
# the allows end users to always know which topics have unread posts in them
# and which topics are new. This is used in various places in the UI, such as
# counters, indicators, and messages at the top of topic lists, so the user
# knows there is something worth reading at a glance.
#
# The TopicTrackingState.report data is preloaded in ApplicationController
# for the current user under the topicTrackingStates key, and the existing
# state is loaded into memory on page load. From there the MessageBus is
# used to keep topic state up to date, as well as syncing with topics from
# corresponding lists fetched from the server (e.g. the /new, /latest,
# /unread topic lists).
#
# See discourse/app/models/topic-tracking-state.js
class TopicTrackingState

  include ActiveModel::SerializerSupport

  UNREAD_MESSAGE_TYPE = "unread"
  LATEST_MESSAGE_TYPE = "latest"
  MUTED_MESSAGE_TYPE = "muted"
  UNMUTED_MESSAGE_TYPE = "unmuted"
  NEW_TOPIC_MESSAGE_TYPE = "new_topic"
  RECOVER_MESSAGE_TYPE = "recover"
  DELETE_MESSAGE_TYPE = "delete"
  DESTROY_MESSAGE_TYPE = "destroy"
  READ_MESSAGE_TYPE = "read"
  DISMISS_NEW_MESSAGE_TYPE = "dismiss_new"
  MAX_TOPICS = 5000

  attr_accessor :user_id,
                :topic_id,
                :highest_post_number,
                :last_read_post_number,
                :created_at,
                :category_id,
                :notification_level,
                :tags

  def self.publish_new(topic)
    return unless topic.regular?

    tag_ids, tags = nil
    if SiteSetting.tagging_enabled
      tag_ids, tags = topic.tags.pluck(:id, :name).transpose
    end

    payload = {
      last_read_post_number: nil,
      highest_post_number: 1,
      created_at: topic.created_at,
      topic_id: topic.id,
      category_id: topic.category_id,
      archetype: topic.archetype,
      created_in_new_period: true
    }

    if tags
      payload[:tags] = tags
      payload[:topic_tag_ids] = tag_ids
    end

    message = {
      topic_id: topic.id,
      message_type: NEW_TOPIC_MESSAGE_TYPE,
      payload: payload
    }

    group_ids = topic.category && topic.category.secure_group_ids

    MessageBus.publish("/new", message.as_json, group_ids: group_ids)
    publish_read(topic.id, 1, topic.user_id)
  end

  def self.publish_latest(topic, staff_only = false)
    return unless topic.regular?

    tag_ids, tags = nil
    if SiteSetting.tagging_enabled
      tag_ids, tags = topic.tags.pluck(:id, :name).transpose
    end

    message = {
      topic_id: topic.id,
      message_type: LATEST_MESSAGE_TYPE,
      payload: {
        bumped_at: topic.bumped_at,
        category_id: topic.category_id,
        archetype: topic.archetype
      }
    }

    if tags
      message[:payload][:tags] = tags
      message[:payload][:topic_tag_ids] = tag_ids
    end

    group_ids =
      if staff_only
        [Group::AUTO_GROUPS[:staff]]
      else
        topic.category && topic.category.secure_group_ids
      end
    MessageBus.publish("/latest", message.as_json, group_ids: group_ids)
  end

  def self.unread_channel_key(user_id)
    "/unread/#{user_id}"
  end

  def self.publish_muted(topic)
    user_ids = topic.topic_users
      .where(notification_level: NotificationLevels.all[:muted])
      .joins(:user)
      .where("users.last_seen_at > ?", 7.days.ago)
      .order("users.last_seen_at DESC")
      .limit(100)
      .pluck(:user_id)
    return if user_ids.blank?
    message = {
      topic_id: topic.id,
      message_type: MUTED_MESSAGE_TYPE,
    }
    MessageBus.publish("/latest", message.as_json, user_ids: user_ids)
  end

  def self.publish_unmuted(topic)
    return if !SiteSetting.mute_all_categories_by_default
    user_ids = User.watching_topic_when_mute_categories_by_default(topic)
      .where("users.last_seen_at > ?", 7.days.ago)
      .order("users.last_seen_at DESC")
      .limit(100)
      .pluck(:id)
    return if user_ids.blank?
    message = {
      topic_id: topic.id,
      message_type: UNMUTED_MESSAGE_TYPE,
    }
    MessageBus.publish("/latest", message.as_json, user_ids: user_ids)
  end

  def self.publish_unread(post)
    return unless post.topic.regular?
    # TODO at high scale we are going to have to defer this,
    #   perhaps cut down to users that are around in the last 7 days as well

    group_ids =
      if post.post_type == Post.types[:whisper]
        [Group::AUTO_GROUPS[:staff]]
      else
        post.topic.category && post.topic.category.secure_group_ids
      end

    tags = nil
    tag_ids = nil
    if include_tags_in_report?
      tag_ids, tags = post.topic.tags.pluck(:id, :name).transpose
    end

    TopicUser
      .tracking(post.topic_id)
      .includes(user: :user_stat)
      .select([:user_id, :last_read_post_number, :notification_level])
      .each do |tu|

      payload = {
        last_read_post_number: tu.last_read_post_number,
        highest_post_number: post.post_number,
        updated_at: post.topic.updated_at,
        created_at: post.created_at,
        category_id: post.topic.category_id,
        notification_level: tu.notification_level,
        archetype: post.topic.archetype,
        first_unread_at: tu.user.user_stat.first_unread_at,
        unread_not_too_old: true
      }

      if tags
        payload[:tags] = tags
        payload[:topic_tag_ids] = tag_ids
      end

      message = {
        topic_id: post.topic_id,
        message_type: UNREAD_MESSAGE_TYPE,
        payload: payload
      }

      MessageBus.publish(self.unread_channel_key(tu.user_id), message.as_json, group_ids: group_ids)
    end

  end

  def self.publish_recover(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: RECOVER_MESSAGE_TYPE
    }

    MessageBus.publish("/recover", message.as_json, group_ids: group_ids)

  end

  def self.publish_delete(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: DELETE_MESSAGE_TYPE
    }

    MessageBus.publish("/delete", message.as_json, group_ids: group_ids)
  end

  def self.publish_destroy(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: DESTROY_MESSAGE_TYPE
    }

    MessageBus.publish("/destroy", message.as_json, group_ids: group_ids)
  end

  def self.publish_read(topic_id, last_read_post_number, user_id, notification_level = nil)
    highest_post_number = DB.query_single("SELECT highest_post_number FROM topics WHERE id = ?", topic_id).first

    message = {
      topic_id: topic_id,
      message_type: READ_MESSAGE_TYPE,
      payload: {
        last_read_post_number: last_read_post_number,
        highest_post_number: highest_post_number,
        topic_id: topic_id,
        notification_level: notification_level
      }
    }

    MessageBus.publish(self.unread_channel_key(user_id), message.as_json, user_ids: [user_id])
  end

  def self.publish_dismiss_new(user_id, topic_ids: [])
    message = {
      message_type: DISMISS_NEW_MESSAGE_TYPE,
      payload: {
        topic_ids: topic_ids
      }
    }
    MessageBus.publish(self.unread_channel_key(user_id), message.as_json, user_ids: [user_id])
  end

  def self.new_filter_sql
    TopicQuery.new_filter(
      Topic, treat_as_new_topic_clause_sql: treat_as_new_topic_clause
    ).where_clause.ast.to_sql +
      " AND topics.created_at > :min_new_topic_date" +
      " AND dismissed_topic_users.id IS NULL"
  end

  def self.unread_filter_sql(staff: false)
    TopicQuery.unread_filter(Topic, staff: staff).where_clause.ast.to_sql
  end

  def self.treat_as_new_topic_clause
    User.where("GREATEST(CASE
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(u.previous_visit_at,u.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(uo.new_topic_duration_minutes, :default_duration))
               END, u.created_at, :min_date)",
               treat_as_new_topic_params
              ).where_clause.ast.to_sql
  end

  def self.treat_as_new_topic_params
    {
      now: DateTime.now,
      last_visit: User::NewTopicDuration::LAST_VISIT,
      always: User::NewTopicDuration::ALWAYS,
      default_duration: SiteSetting.default_other_new_topic_duration_minutes,
      min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
    }
  end

  def self.include_tags_in_report?
    SiteSetting.tagging_enabled && @include_tags_in_report
  end

  def self.include_tags_in_report=(v)
    @include_tags_in_report = v
  end

  # Sam: this is a hairy report, in particular I need custom joins and fancy conditions
  #  Dropping to sql_builder so I can make sense of it.
  #
  # Keep in mind, we need to be able to filter on a GROUP of users, and zero in on topic
  #  all our existing scope work does not do this
  #
  # This code needs to be VERY efficient as it is triggered via the message bus and may steal
  #  cycles from usual requests
  def self.report(user, topic_id = nil)
    tag_ids = muted_tag_ids(user)
    sql = new_and_unread_sql(topic_id, user, tag_ids)
    sql = tags_included_wrapped_sql(sql)

    report = DB.query(
      sql + "\n\n LIMIT :max_topics",
      {
        user_id: user.id,
        topic_id: topic_id,
        min_new_topic_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
        max_topics: TopicTrackingState::MAX_TOPICS,
      }
      .merge(treat_as_new_topic_params)
    )

    report
  end

  def self.new_and_unread_sql(topic_id, user, tag_ids)
    sql = report_raw_sql(
      topic_id: topic_id,
      skip_unread: true,
      skip_order: true,
      staff: user.staff?,
      admin: user.admin?,
      user: user,
      muted_tag_ids: tag_ids
    )

    sql << "\nUNION ALL\n\n"

    sql << report_raw_sql(
      topic_id: topic_id,
      skip_new: true,
      skip_order: true,
      staff: user.staff?,
      filter_old_unread: true,
      admin: user.admin?,
      user: user,
      muted_tag_ids: tag_ids
    )
  end

  def self.tags_included_wrapped_sql(sql)
    if SiteSetting.tagging_enabled && TopicTrackingState.include_tags_in_report?
      return <<~SQL
        WITH tags_included_cte AS (
          #{sql}
        )
        SELECT *, (
          SELECT ARRAY_AGG(name) from topic_tags
             JOIN tags on tags.id = topic_tags.tag_id
             WHERE topic_id = tags_included_cte.topic_id
          ) tags
        FROM tags_included_cte
      SQL
    end

    sql
  end

  def self.muted_tag_ids(user)
    TagUser.lookup(user, :muted).pluck(:tag_id)
  end

  def self.report_raw_sql(
    user:,
    muted_tag_ids:,
    topic_id: nil,
    filter_old_unread: false,
    skip_new: false,
    skip_unread: false,
    skip_order: false,
    staff: false,
    admin: false,
    select: nil,
    custom_state_filter: nil,
    additional_join_sql: nil
  )
    unread =
      if skip_unread
        "1=0"
      else
        unread_filter_sql
      end

    filter_old_unread_sql =
      if filter_old_unread
        " topics.updated_at >= us.first_unread_at AND "
      else
        ""
      end

    new =
      if skip_new
        "1=0"
      else
        new_filter_sql
      end

    select_sql = select || "
           DISTINCT topics.id as topic_id,
           u.id as user_id,
           topics.created_at,
           topics.updated_at,
           #{highest_post_number_column_select(staff)},
           last_read_post_number,
           c.id as category_id,
           tu.notification_level,
           us.first_unread_at,
           GREATEST(
              CASE
              WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
              WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(
                u.previous_visit_at,u.created_at
              )
              ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(uo.new_topic_duration_minutes, :default_duration))
              END, u.created_at, :min_date
           ) AS treat_as_new_topic_start_date"

    category_filter =
      if admin
        ""
      else
        append = "OR u.admin" if !admin
        <<~SQL
          (
           NOT c.read_restricted #{append} OR c.id IN (
              SELECT c2.id FROM categories c2
              JOIN category_groups cg ON cg.category_id = c2.id
              JOIN group_users gu ON gu.user_id = :user_id AND cg.group_id = gu.group_id
              WHERE c2.read_restricted )
          ) AND
        SQL
      end

    visibility_filter =
      if staff
        ""
      else
        append = "OR u.admin OR u.moderator" if !staff
        "(topics.visible #{append}) AND"
      end

    tags_filter = ""

    if muted_tag_ids.present? && ['always', 'only_muted'].include?(SiteSetting.remove_muted_tags_from_latest)
      existing_tags_sql = "(select array_agg(tag_id) from topic_tags where topic_tags.topic_id = topics.id)"
      muted_tags_array_sql = "ARRAY[#{muted_tag_ids.join(',')}]"

      if SiteSetting.remove_muted_tags_from_latest == 'always'
        tags_filter = <<~SQL
          NOT (
            COALESCE(#{existing_tags_sql}, ARRAY[]::int[]) && #{muted_tags_array_sql}
          ) AND
        SQL
      else # only muted
        tags_filter = <<~SQL
          NOT (
            COALESCE(#{existing_tags_sql}, ARRAY[-999]) <@ #{muted_tags_array_sql}
          ) AND
        SQL
      end
    end

    sql = +<<~SQL
      SELECT #{select_sql}
      FROM topics
      JOIN users u on u.id = :user_id
      JOIN user_stats AS us ON us.user_id = u.id
      JOIN user_options AS uo ON uo.user_id = u.id
      JOIN categories c ON c.id = topics.category_id
      LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
      LEFT JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{user.id}
      LEFT JOIN dismissed_topic_users ON dismissed_topic_users.topic_id = topics.id AND dismissed_topic_users.user_id = #{user.id}
      #{additional_join_sql}
      WHERE u.id = :user_id AND
            #{filter_old_unread_sql}
            topics.archetype <> 'private_message' AND
            #{custom_state_filter ? custom_state_filter : "((#{unread}) OR (#{new})) AND"}
            #{visibility_filter}
            #{tags_filter}
            topics.deleted_at IS NULL AND
            #{category_filter}
            NOT (
              #{(skip_new && skip_unread) ? "" : "last_read_post_number IS NULL AND"}
              (
                COALESCE(category_users.notification_level, #{CategoryUser.default_notification_level}) = #{CategoryUser.notification_levels[:muted]}
                AND tu.notification_level <= #{TopicUser.notification_levels[:regular]}
              )
            )
    SQL

    if topic_id
      sql << " AND topics.id = :topic_id"
    end

    unless skip_order
      sql << " ORDER BY topics.bumped_at DESC"
    end

    sql
  end

  def self.highest_post_number_column_select(staff)
    "#{staff ? "topics.highest_staff_post_number AS highest_post_number" : "topics.highest_post_number"}"
  end

  def self.publish_private_message(topic, archive_user_id: nil,
                                          post: nil,
                                          group_archive: false)

    return unless topic.private_message?
    channels = {}

    allowed_user_ids = topic.allowed_users.pluck(:id)

    if post && allowed_user_ids.include?(post.user_id)
      channels["/private-messages/sent"] = [post.user_id]
    end

    if archive_user_id
      user_ids = [archive_user_id]

      [
        "/private-messages/archive",
        "/private-messages/inbox",
        "/private-messages/sent",
      ].each do |channel|
        channels[channel] = user_ids
      end
    end

    if channels.except("/private-messages/sent").blank?
      channels["/private-messages/inbox"] = allowed_user_ids
    end

    topic.allowed_groups.each do |group|
      group_user_ids = group.users.pluck(:id)
      next if group_user_ids.blank?
      group_channels = []
      channel_prefix = "/private-messages/group/#{group.name.downcase}"
      group_channels << "#{channel_prefix}/inbox"
      group_channels << "#{channel_prefix}/archive" if group_archive
      group_channels.each { |channel| channels[channel] = group_user_ids }
    end

    message = {
      topic_id: topic.id
    }

    channels.each do |channel, ids|
      if ids.present?
        MessageBus.publish(
          channel,
          message.as_json,
          user_ids: ids
        )
      end
    end
  end

  def self.publish_read_indicator_on_write(topic_id, last_read_post_number, user_id)
    topic = Topic.includes(:allowed_groups).select(:highest_post_number, :archetype, :id).find_by(id: topic_id)

    if topic&.private_message?
      groups = read_allowed_groups_of(topic)
      update_topic_list_read_indicator(topic, groups, topic.highest_post_number, user_id, true)
    end
  end

  def self.publish_read_indicator_on_read(topic_id, last_read_post_number, user_id)
    topic = Topic.includes(:allowed_groups).select(:highest_post_number, :archetype, :id).find_by(id: topic_id)

    if topic&.private_message?
      groups = read_allowed_groups_of(topic)
      post = Post.find_by(topic_id: topic.id, post_number: last_read_post_number)
      trigger_post_read_count_update(post, groups, last_read_post_number, user_id)
      update_topic_list_read_indicator(topic, groups, last_read_post_number, user_id, false)
    end
  end

  def self.read_allowed_groups_of(topic)
    topic.allowed_groups
      .joins(:group_users)
      .where(publish_read_state: true)
      .select('ARRAY_AGG(group_users.user_id) AS members', :name, :id)
      .group('groups.id')
  end

  def self.update_topic_list_read_indicator(topic, groups, last_read_post_number, user_id, write_event)
    return unless last_read_post_number == topic.highest_post_number
    message = { topic_id: topic.id, show_indicator: write_event }.as_json
    groups_to_update = []

    groups.each do |group|
      member = group.members.include?(user_id)

      member_writing = (write_event && member)
      non_member_reading = (!write_event && !member)
      next if non_member_reading || member_writing

      groups_to_update << group
    end

    return if groups_to_update.empty?
    MessageBus.publish("/private-messages/unread-indicator/#{topic.id}", message, user_ids: groups_to_update.flat_map(&:members))
  end

  def self.trigger_post_read_count_update(post, groups, last_read_post_number, user_id)
    return if !post
    return if groups.empty?
    opts = { readers_count: post.readers_count, reader_id: user_id }
    post.publish_change_to_clients!(:read, opts)
  end
end
