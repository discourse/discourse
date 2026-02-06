# frozen_string_literal: true

module Chat
  # Searches for chatables (users, groups, category channels, direct message channels).
  #
  # Results include a `match_quality` field for ranking:
  #   - MATCH_QUALITY_EXACT (1): name/username equals search term
  #   - MATCH_QUALITY_PREFIX (2): name/username starts with search term
  #   - MATCH_QUALITY_PARTIAL (3): name/username contains search term
  #
  # @example
  #   Chat::SearchChatable.call(params: { term: "bob" }, guardian: guardian)
  #
  class SearchChatable
    include Service::Base

    SEARCH_RESULT_LIMIT = 10

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :term
    #   @return [Service::Base::Context]

    params do
      attribute :term, :string, default: ""
      attribute :include_users, :boolean, default: true
      attribute :include_groups, :boolean, default: true
      attribute :include_category_channels, :boolean, default: true
      attribute :include_direct_message_channels, :boolean, default: true
      attribute :excluded_memberships_channel_id, :integer

      after_validation { self.term = term&.downcase&.strip&.sub(/\A[@#]+/, "") }
    end

    model :memberships, optional: true
    model :users, optional: true
    model :groups, optional: true
    model :category_channels, optional: true
    model :direct_message_channels, optional: true

    private

    def fetch_memberships(guardian:)
      ::Chat::ChannelMembershipManager.all_for_user(guardian.user)
    end

    def fetch_users(guardian:, params:)
      return unless params.include_users
      return unless guardian.can_create_direct_message?
      search_users(params, guardian)
    end

    def fetch_groups(guardian:, params:)
      return unless params.include_groups
      return unless guardian.can_create_direct_message?
      search_groups(params, guardian)
    end

    def fetch_category_channels(guardian:, params:)
      return unless params.include_category_channels
      return unless SiteSetting.enable_public_channels
      search_category_channels(params, guardian)
    end

    def fetch_direct_message_channels(guardian:, params:, users:)
      return unless params.include_direct_message_channels
      return unless guardian.can_create_direct_message?
      search_direct_message_channels(guardian, params, users)
    end

    def search_users(params, guardian)
      user_search = ::UserSearch.new(params.term, limit: SEARCH_RESULT_LIMIT)

      if params.term.blank?
        user_search = user_search.scoped_users
      else
        user_search = user_search.search
      end

      allowed_bot_user_ids =
        DiscoursePluginRegistry.apply_modifier(:chat_allowed_bot_user_ids, [], guardian)

      user_search = user_search.real(allowed_bot_user_ids:)
      user_search = user_search.includes(:user_option)

      if params.excluded_memberships_channel_id
        user_search =
          user_search.where(
            "NOT EXISTS (SELECT 1 FROM user_chat_channel_memberships WHERE user_id = users.id AND chat_channel_id = ?)",
            params.excluded_memberships_channel_id,
          )
      end

      filter_term = params.term.to_s
      like_term = User.sanitize_sql_like(filter_term)
      escaped_exact = User.connection.quote(filter_term)
      escaped_prefix = User.connection.quote("#{like_term}%")

      select_sql = <<~SQL
        users.*,
        CASE
          WHEN users.username_lower = #{escaped_exact} THEN #{ChannelFetcher::MATCH_QUALITY_EXACT}
          WHEN users.username_lower LIKE #{escaped_prefix} THEN #{ChannelFetcher::MATCH_QUALITY_PREFIX}
          ELSE #{ChannelFetcher::MATCH_QUALITY_PARTIAL}
        END AS match_quality
      SQL

      # need to `reorder` to override the ordering applied in `UserSearch#search`
      user_search.select(select_sql).reorder("match_quality ASC, users.username_lower ASC")
    end

    def search_groups(params, guardian)
      # NOTE: Do NOT eager load users here (e.g. `.includes(users: ...)`).
      # Groups can have 100k+ members and loading them causes request timeouts.
      # The serializer uses SQL COUNT queries instead.
      filter_term = params.term.to_s
      like_term = Group.sanitize_sql_like(filter_term)
      escaped_exact = Group.connection.quote(filter_term)
      escaped_prefix = Group.connection.quote("#{like_term}%")

      select_sql = <<~SQL
        groups.*,
        CASE
          WHEN LOWER(groups.name) = #{escaped_exact} THEN #{ChannelFetcher::MATCH_QUALITY_EXACT}
          WHEN LOWER(groups.name) LIKE #{escaped_prefix} THEN #{ChannelFetcher::MATCH_QUALITY_PREFIX}
          ELSE #{ChannelFetcher::MATCH_QUALITY_PARTIAL}
        END AS match_quality
      SQL

      where_sql = <<~SQL
        LOWER(groups.name) = :exact
        OR LOWER(groups.name) LIKE :prefix
        OR LOWER(groups.name) LIKE :partial
        OR LOWER(groups.full_name) LIKE :partial
      SQL

      Group
        .visible_groups(guardian.user)
        .members_visible_groups(guardian.user)
        .where(where_sql, exact: filter_term, prefix: "#{like_term}%", partial: "%#{like_term}%")
        .select(select_sql)
        .order("match_quality ASC, groups.name ASC")
        .limit(SEARCH_RESULT_LIMIT)
    end

    def search_category_channels(params, guardian)
      ::Chat::ChannelFetcher.secured_public_channel_search(
        guardian,
        status: :open,
        filter: params.term,
        filter_on_category_name: false,
        limit: SEARCH_RESULT_LIMIT,
      )
    end

    def search_direct_message_channels(guardian, params, users)
      channels =
        ::Chat::ChannelFetcher.secured_direct_message_channels_search(
          guardian.user.id,
          guardian,
          filter: params.term,
          limit: SEARCH_RESULT_LIMIT,
        ) || []

      # skip 1:1s when search returns users
      if params.include_users && users.present?
        channels.reject! do |channel|
          other_user_ids = channel.allowed_user_ids - [guardian.user.id]
          other_user_ids.size <= 1
        end
      end

      channels
    end
  end
end
