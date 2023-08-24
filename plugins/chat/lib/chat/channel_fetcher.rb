# frozen_string_literal: true

module Chat
  class ChannelFetcher
    MAX_PUBLIC_CHANNEL_RESULTS = 50

    def self.structured(guardian, include_threads: false)
      memberships = Chat::ChannelMembershipManager.all_for_user(guardian.user)
      public_channels = secured_public_channels(guardian, status: :open, following: true)
      direct_message_channels = secured_direct_message_channels(guardian.user.id, guardian)
      {
        public_channels: public_channels,
        direct_message_channels: direct_message_channels,
        memberships: memberships,
        tracking:
          tracking_state(
            public_channels.map(&:id) + direct_message_channels.map(&:id),
            guardian,
            include_threads: include_threads,
          ),
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
          Chat::Channel
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

      Chat::Channel
        .with_categories
        .where(chatable_type: Chat::Channel.public_channel_chatable_types)
        .where("chat_channels.id IN (#{allowed_channel_ids})")
        .where("chat_channels.slug IN (:slugs)", slugs: slugs)
        .limit(1)
    end

    def self.secured_public_channel_search(guardian, options = {})
      return ::Chat::Channel.none if !SiteSetting.enable_public_channels

      allowed_channel_ids = generate_allowed_channel_ids_sql(guardian, exclude_dm_channels: true)

      channels = Chat::Channel.includes(:last_message, chatable: [:topic_only_relative_url])
      channels = channels.includes(:chat_channel_archive) if options[:include_archives]

      channels =
        channels
          .with_categories
          .where(chatable_type: Chat::Channel.public_channel_chatable_types)
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
          channels.where(sql, filter: filter_sql).order(
            "chat_channels.name ASC, categories.name ASC",
          )
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

    def self.secured_public_channels(guardian, options = { following: true })
      channels =
        secured_public_channel_search(
          guardian,
          options.merge(include_archives: true, filter_on_category_name: true),
        )

      channels = channels.to_a
      preload_custom_fields_for(channels)
      channels
    end

    def self.preload_custom_fields_for(channels)
      preload_fields = Category.instance_variable_get(:@custom_field_types).keys
      Category.preload_custom_fields(
        channels
          .select { |c| c.chatable_type == "Category" || c.chatable_type == "category" }
          .map(&:chatable),
        preload_fields,
      )
    end

    def self.secured_direct_message_channels(user_id, guardian)
      secured_direct_message_channels_search(user_id, guardian, following: true)
    end

    def self.secured_direct_message_channels_search(user_id, guardian, options = {})
      query =
        Chat::Channel.strict_loading.includes(
          last_message: [:uploads],
          chatable: [{ direct_message_users: [user: :user_option] }, :users],
        )
      query = query.includes(chatable: [{ users: :user_status }]) if SiteSetting.enable_user_status
      query = query.joins(:user_chat_channel_memberships)
      query =
        query.joins(
          "LEFT JOIN chat_messages last_message ON last_message.id = chat_channels.last_message_id",
        )

      scoped_channels =
        Chat::Channel
          .joins(
            "INNER JOIN direct_message_channels ON direct_message_channels.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'DirectMessage'",
          )
          .joins(
            "INNER JOIN direct_message_users ON direct_message_users.direct_message_channel_id = direct_message_channels.id",
          )
          .where("direct_message_users.user_id = :user_id", user_id: user_id)

      if options[:user_ids]
        scoped_channels =
          scoped_channels.where(
            "EXISTS (
              SELECT 1
              FROM direct_message_channels AS dmc
              INNER JOIN direct_message_users AS dmu ON dmu.direct_message_channel_id = dmc.id
              WHERE dmc.id = chat_channels.chatable_id AND dmu.user_id IN (:user_ids)
            )",
            user_ids: options[:user_ids],
          )
      end

      if options.key?(:following)
        query =
          query.where(
            user_chat_channel_memberships: {
              user_id: user_id,
              following: options[:following],
            },
          )
      else
        query = query.where(user_chat_channel_memberships: { user_id: user_id })
      end

      query =
        query
          .where(chatable_type: Chat::Channel.direct_channel_chatable_types)
          .where(chat_channels: { id: scoped_channels })
          .order("last_message.created_at DESC NULLS LAST")

      channels = query.to_a
      preload_fields =
        User.allowed_user_custom_fields(guardian) +
          UserField.all.pluck(:id).map { |fid| "#{User::USER_FIELD_PREFIX}#{fid}" }
      User.preload_custom_fields(channels.map { |c| c.chatable.users }.flatten, preload_fields)
      channels
    end

    def self.tracking_state(channel_ids, guardian, include_threads: false)
      Chat::TrackingState.call(
        channel_ids: channel_ids,
        guardian: guardian,
        include_missing_memberships: true,
        include_threads: include_threads,
      ).report
    end

    def self.find_with_access_check(channel_id_or_slug, guardian)
      base_channel_relation = Chat::Channel.includes(:chatable)

      if guardian.is_staff?
        base_channel_relation = base_channel_relation.includes(:chat_channel_archive)
      end

      chat_channel = base_channel_relation.find_by_id_or_slug(channel_id_or_slug)

      raise Discourse::NotFound if chat_channel.blank?
      raise Discourse::InvalidAccess if !guardian.can_join_chat_channel?(chat_channel)
      chat_channel
    end
  end
end
