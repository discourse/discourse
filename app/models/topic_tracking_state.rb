# frozen_string_literal: true

# this class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using the mssage bus
# the allows end users to always know which topics have unread posts in them
# and which topics are new

class TopicTrackingState

  include ActiveModel::SerializerSupport

  CHANNEL = "/user-tracking"
  UNREAD_MESSAGE_TYPE = "unread".freeze
  LATEST_MESSAGE_TYPE = "latest".freeze

  attr_accessor :user_id,
                :topic_id,
                :highest_post_number,
                :last_read_post_number,
                :created_at,
                :category_id,
                :notification_level

  def self.publish_new(topic)
    return unless topic.regular?

    message = {
      topic_id: topic.id,
      message_type: "new_topic",
      payload: {
        last_read_post_number: nil,
        highest_post_number: 1,
        created_at: topic.created_at,
        topic_id: topic.id,
        category_id: topic.category_id,
        archetype: topic.archetype,
        topic_tag_ids: topic.tags.pluck(:id)
      }
    }

    group_ids = topic.category && topic.category.secure_group_ids

    MessageBus.publish("/new", message.as_json, group_ids: group_ids)
    publish_read(topic.id, 1, topic.user_id)
  end

  def self.publish_latest(topic, staff_only = false)
    return unless topic.regular?

    message = {
      topic_id: topic.id,
      message_type: LATEST_MESSAGE_TYPE,
      payload: {
        bumped_at: topic.bumped_at,
        category_id: topic.category_id,
        archetype: topic.archetype,
        topic_tag_ids: topic.tags.pluck(:id)
      }
    }

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

    TopicUser
      .tracking(post.topic_id)
      .select([:user_id, :last_read_post_number, :notification_level])
      .each do |tu|

      message = {
        topic_id: post.topic_id,
        message_type: UNREAD_MESSAGE_TYPE,
        payload: {
          last_read_post_number: tu.last_read_post_number,
          highest_post_number: post.post_number,
          created_at: post.created_at,
          category_id: post.topic.category_id,
          notification_level: tu.notification_level,
          archetype: post.topic.archetype
        }
      }

      MessageBus.publish(self.unread_channel_key(tu.user_id), message.as_json, group_ids: group_ids)
    end

  end

  def self.publish_recover(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: "recover"
    }

    MessageBus.publish("/recover", message.as_json, group_ids: group_ids)

  end

  def self.publish_delete(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: "delete"
    }

    MessageBus.publish("/delete", message.as_json, group_ids: group_ids)
  end

  def self.publish_read(topic_id, last_read_post_number, user_id, notification_level = nil)
    highest_post_number = DB.query_single("SELECT highest_post_number FROM topics WHERE id = ?", topic_id).first

    message = {
      topic_id: topic_id,
      message_type: "read",
      payload: {
        last_read_post_number: last_read_post_number,
        highest_post_number: highest_post_number,
        topic_id: topic_id,
        notification_level: notification_level
      }
    }

    MessageBus.publish(self.unread_channel_key(user_id), message.as_json, user_ids: [user_id])
  end

  def self.publish_dismiss_new(user_id, category_id = nil)
    payload = category_id ? { category_id: category_id } : {}
    message = {
      message_type: "dismiss_new",
      payload: payload
    }
    MessageBus.publish(self.unread_channel_key(user_id), message.as_json, user_ids: [user_id])
  end

  def self.treat_as_new_topic_clause
    User.where("GREATEST(CASE
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(u.previous_visit_at,u.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(uo.new_topic_duration_minutes, :default_duration))
               END, us.new_since, :min_date)",
                now: DateTime.now,
                last_visit: User::NewTopicDuration::LAST_VISIT,
                always: User::NewTopicDuration::ALWAYS,
                default_duration: SiteSetting.default_other_new_topic_duration_minutes,
                min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
              ).where_clause.send(:predicates)[0]
  end

  def self.report(user, topic_id = nil)
    # Sam: this is a hairy report, in particular I need custom joins and fancy conditions
    #  Dropping to sql_builder so I can make sense of it.
    #
    # Keep in mind, we need to be able to filter on a GROUP of users, and zero in on topic
    #  all our existing scope work does not do this
    #
    # This code needs to be VERY efficient as it is triggered via the message bus and may steal
    #  cycles from usual requests
    sql = +report_raw_sql(
      topic_id: topic_id,
      skip_unread: true,
      skip_order: true,
      staff: user.staff?,
      admin: user.admin?,
      user: user,
      muted_tag_ids: muted_tag_ids(user)
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
      muted_tag_ids: muted_tag_ids(user)
    )

    DB.query(
      sql,
        user_id: user.id,
        topic_id: topic_id,
        min_new_topic_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
    )
  end

  def self.muted_tag_ids(user)
    TagUser.lookup(user, :muted).pluck(:tag_id)
  end

  def self.report_raw_sql(opts = nil)
    opts ||= {}

    unread =
      if opts[:skip_unread]
        "1=0"
      else
        TopicQuery
          .unread_filter(Topic, -999, staff: opts && opts[:staff])
          .where_clause.send(:predicates)
          .join(" AND ")
          .gsub("-999", ":user_id")
      end

    filter_old_unread =
      if opts[:filter_old_unread]
        " topics.updated_at >= us.first_unread_at AND "
      else
        ""
      end

    new =
      if opts[:skip_new]
        "1=0"
      else
        TopicQuery.new_filter(Topic, "xxx").where_clause.send(:predicates).join(" AND ").gsub!("'xxx'", treat_as_new_topic_clause) +
          " AND topics.created_at > :min_new_topic_date" +
          " AND (category_users.last_seen_at IS NULL OR topics.created_at > category_users.last_seen_at)"
      end

    select = (opts[:select]) || "
           u.id AS user_id,
           topics.id AS topic_id,
           topics.created_at,
           #{opts[:staff] ? "highest_staff_post_number highest_post_number" : "highest_post_number"},
           last_read_post_number,
           c.id AS category_id,
           tu.notification_level"

    category_filter =
      if opts[:admin]
        ""
      else
        append = "OR u.admin" if !opts.key?(:admin)
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
      if opts[:staff]
        ""
      else
        append = "OR u.admin OR u.moderator" if !opts.key?(:staff)
        "(topics.visible #{append}) AND"
      end

    tags_filter =
      if opts[:muted_tag_ids].present? && SiteSetting.remove_muted_tags_from_latest == 'always'
        <<~SQL
          NOT ((select array_agg(tag_id) from topic_tags where topic_tags.topic_id = topics.id) && ARRAY[#{opts[:muted_tag_ids].join(',')}]) AND
        SQL
      elsif opts[:muted_tag_ids].present? && SiteSetting.remove_muted_tags_from_latest == 'only_muted'
        <<~SQL
          NOT ((select array_agg(tag_id) from topic_tags where topic_tags.topic_id = topics.id) <@ ARRAY[#{opts[:muted_tag_ids].join(',')}]) AND
        SQL
      else
        ""
      end

    sql = +<<~SQL
    SELECT #{select}
    FROM topics
    JOIN users u on u.id = :user_id
    JOIN user_stats AS us ON us.user_id = u.id
    JOIN user_options AS uo ON uo.user_id = u.id
    JOIN categories c ON c.id = topics.category_id
    LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
    LEFT JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{opts[:user].id}
    WHERE u.id = :user_id AND
          #{filter_old_unread}
          topics.archetype <> 'private_message' AND
          ((#{unread}) OR (#{new})) AND
          #{visibility_filter}
          #{tags_filter}
          topics.deleted_at IS NULL AND
          #{category_filter}
          NOT (
            last_read_post_number IS NULL AND
            COALESCE(category_users.notification_level, #{CategoryUser.default_notification_level}) = #{CategoryUser.notification_levels[:muted]}
          )
SQL

    if opts[:topic_id]
      sql << " AND topics.id = :topic_id"
    end

    unless opts[:skip_order]
      sql << " ORDER BY topics.bumped_at DESC"
    end

    sql
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
      group_channels << "/private-messages/group/#{group.name.downcase}"
      group_channels << "#{group_channels.first}/archive" if group_archive
      group_channels.each { |channel| channels[channel] = group_user_ids }
    end

    message = {
      topic_id: topic.id
    }

    channels.each do |channel, ids|
      MessageBus.publish(
        channel,
        message.as_json,
        user_ids: ids
      )
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
