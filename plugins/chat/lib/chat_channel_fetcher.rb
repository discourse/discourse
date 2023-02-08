# frozen_string_literal: true

module Chat::ChatChannelFetcher
  MAX_PUBLIC_CHANNEL_RESULTS = 50

  def self.structured(guardian)
    memberships = Chat::ChatChannelMembershipManager.all_for_user(guardian.user)
    {
      public_channels:
        secured_public_channels(guardian, memberships, status: :open, following: true),
      direct_message_channels:
        secured_direct_message_channels(guardian.user.id, memberships, guardian),
      memberships: memberships,
    }
  end

  def self.all_secured_channel_ids(guardian, following: true)
    allowed_channel_ids_sql = generate_allowed_channel_ids_sql(guardian)

    return DB.query_single(allowed_channel_ids_sql) if !following

    DB.query_single(<<~SQL, user_id: guardian.user.id)
      SELECT chat_channel_id
      FROM user_chat_channel_memberships
      WHERE user_chat_channel_memberships.user_id = :user_id
      AND user_chat_channel_memberships.chat_channel_id IN (
        #{allowed_channel_ids_sql}
      )
    SQL
  end

  def self.generate_allowed_channel_ids_sql(guardian, exclude_dm_channels: false)
    category_channel_sql =
      Category
        .post_create_allowed(guardian)
        .joins(
          "INNER JOIN chat_channels ON chat_channels.chatable_id = categories.id AND chat_channels.chatable_type = 'Category'",
        )
        .select("chat_channels.id")
        .to_sql
    dm_channel_sql = ""
    if !exclude_dm_channels
      dm_channel_sql = <<~SQL
      UNION

      -- secured direct message chat channels
      #{
        ChatChannel
          .select(:id)
          .joins(
            "INNER JOIN direct_message_channels ON direct_message_channels.id = chat_channels.chatable_id
            AND chat_channels.chatable_type = 'DirectMessage'
        INNER JOIN direct_message_users ON direct_message_users.direct_message_channel_id = direct_message_channels.id",
          )
          .where("direct_message_users.user_id = :user_id", user_id: guardian.user.id)
          .to_sql
      }
      SQL
    end

    <<~SQL
      -- secured category chat channels
      #{category_channel_sql}
      #{dm_channel_sql}
    SQL
  end

  def self.secured_public_channel_slug_lookup(guardian, slugs)
    allowed_channel_ids = generate_allowed_channel_ids_sql(guardian, exclude_dm_channels: true)

    ChatChannel
      .joins(
        "LEFT JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'",
      )
      .where(chatable_type: ChatChannel.public_channel_chatable_types)
      .where("chat_channels.id IN (#{allowed_channel_ids})")
      .where("chat_channels.slug IN (:slugs)", slugs: slugs)
      .limit(1)
  end

  def self.secured_public_channel_search(guardian, options = {})
    allowed_channel_ids = generate_allowed_channel_ids_sql(guardian, exclude_dm_channels: true)

    channels = ChatChannel.includes(chatable: [:topic_only_relative_url])
    channels = channels.includes(:chat_channel_archive) if options[:include_archives]

    channels =
      channels
        .joins(
          "LEFT JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'",
        )
        .where(chatable_type: ChatChannel.public_channel_chatable_types)
        .where("chat_channels.id IN (#{allowed_channel_ids})")

    channels = channels.where(status: options[:status]) if options[:status].present?

    if options[:filter].present?
      category_filter =
        (options[:filter_on_category_name] ? "OR categories.name ILIKE :filter" : "")

      sql =
        "chat_channels.name ILIKE :filter OR chat_channels.slug ILIKE :filter #{category_filter}"
      if options[:match_filter_on_starts_with]
        filter_sql = "#{options[:filter].downcase}%"
      else
        filter_sql = "%#{options[:filter].downcase}%"
      end

      channels =
        channels.where(sql, filter: filter_sql).order("chat_channels.name ASC, categories.name ASC")
    end

    if options.key?(:slugs)
      channels = channels.where("chat_channels.slug IN (:slugs)", slugs: options[:slugs])
    end

    if options.key?(:following)
      if options[:following]
        channels =
          channels.joins(:user_chat_channel_memberships).where(
            user_chat_channel_memberships: {
              user_id: guardian.user.id,
              following: true,
            },
          )
      else
        channels =
          channels.where(
            "chat_channels.id NOT IN (SELECT chat_channel_id FROM user_chat_channel_memberships uccm WHERE uccm.chat_channel_id = chat_channels.id AND following IS TRUE AND user_id = ?)",
            guardian.user.id,
          )
      end
    end

    options[:limit] = (options[:limit] || MAX_PUBLIC_CHANNEL_RESULTS).to_i.clamp(
      1,
      MAX_PUBLIC_CHANNEL_RESULTS,
    )
    options[:offset] = [options[:offset].to_i, 0].max

    channels.limit(options[:limit]).offset(options[:offset])
  end

  def self.secured_public_channels(guardian, memberships, options = { following: true })
    channels =
      secured_public_channel_search(
        guardian,
        options.merge(include_archives: true, filter_on_category_name: true),
      )

    decorate_memberships_with_tracking_data(guardian, channels, memberships)
    channels = channels.to_a
    preload_custom_fields_for(channels)
    channels
  end

  def self.preload_custom_fields_for(channels)
    preload_fields = Category.instance_variable_get(:@custom_field_types).keys
    Category.preload_custom_fields(
      channels.select { |c| c.chatable_type == "Category" }.map(&:chatable),
      preload_fields,
    )
  end

  def self.secured_direct_message_channels(user_id, memberships, guardian)
    query = ChatChannel.includes(chatable: [{ direct_message_users: :user }, :users])
    query = query.includes(chatable: [{ users: :user_status }]) if SiteSetting.enable_user_status

    channels =
      query
        .joins(:user_chat_channel_memberships)
        .where(user_chat_channel_memberships: { user_id: user_id, following: true })
        .where(chatable_type: "DirectMessage")
        .where("chat_channels.id IN (#{generate_allowed_channel_ids_sql(guardian)})")
        .order(last_message_sent_at: :desc)
        .to_a

    preload_fields =
      User.allowed_user_custom_fields(guardian) +
        UserField.all.pluck(:id).map { |fid| "#{User::USER_FIELD_PREFIX}#{fid}" }
    User.preload_custom_fields(channels.map { |c| c.chatable.users }.flatten, preload_fields)

    decorate_memberships_with_tracking_data(guardian, channels, memberships)
  end

  def self.decorate_memberships_with_tracking_data(guardian, channels, memberships)
    unread_counts_per_channel = unread_counts(channels, guardian.user.id)

    mention_notifications =
      Notification.unread.where(
        user_id: guardian.user.id,
        notification_type: Notification.types[:chat_mention],
      )
    mention_notification_data = mention_notifications.map { |m| JSON.parse(m.data) }

    channels.each do |channel|
      membership = memberships.find { |m| m.chat_channel_id == channel.id }

      if membership
        membership.unread_mentions =
          mention_notification_data.count do |data|
            data["chat_channel_id"] == channel.id &&
              data["chat_message_id"] > (membership.last_read_message_id || 0)
          end

        membership.unread_count = unread_counts_per_channel[channel.id] if !membership.muted
      end
    end
  end

  def self.unread_counts(channels, user_id)
    unread_counts = DB.query_array(<<~SQL, channel_ids: channels.map(&:id), user_id: user_id).to_h
      SELECT cc.id, COUNT(*) as count
      FROM chat_messages cm
      JOIN chat_channels cc ON cc.id = cm.chat_channel_id
      JOIN user_chat_channel_memberships uccm ON uccm.chat_channel_id = cc.id
      WHERE cc.id IN (:channel_ids)
        AND cm.user_id != :user_id
        AND uccm.user_id = :user_id
        AND cm.id > COALESCE(uccm.last_read_message_id, 0)
        AND cm.deleted_at IS NULL
      GROUP BY cc.id
    SQL
    unread_counts.default = 0
    unread_counts
  end

  def self.find_with_access_check(channel_id_or_name, guardian)
    begin
      channel_id_or_name = Integer(channel_id_or_name)
    rescue ArgumentError
    end

    base_channel_relation =
      ChatChannel.includes(:chatable).joins(
        "LEFT JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'",
      )

    if guardian.user.staff?
      base_channel_relation = base_channel_relation.includes(:chat_channel_archive)
    end

    if channel_id_or_name.is_a? Integer
      chat_channel = base_channel_relation.find_by(id: channel_id_or_name)
    else
      chat_channel =
        base_channel_relation.find_by(
          "LOWER(categories.name) = :name OR LOWER(chat_channels.name) = :name",
          name: channel_id_or_name.downcase,
        )
    end

    raise Discourse::NotFound if chat_channel.blank?
    raise Discourse::InvalidAccess if !guardian.can_preview_chat_channel?(chat_channel)
    chat_channel
  end
end
