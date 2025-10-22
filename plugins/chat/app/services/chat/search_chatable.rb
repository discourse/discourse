# frozen_string_literal: true

module Chat
  # Returns a list of chatables (users, groups ,category channels, direct message channels) that can be chatted with.
  #
  # @example
  #  Chat::SearchChatable.call(params: { term: "@bob" }, guardian: guardian)
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

      after_validation { self.term = term&.downcase&.strip&.gsub(/^[@#]+/, "") }
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

      user_search = user_search.real(allowed_bot_user_ids: allowed_bot_user_ids)
      user_search = user_search.includes(:user_option)

      if params.excluded_memberships_channel_id
        user_search =
          user_search.where(
            "NOT EXISTS (SELECT 1 FROM user_chat_channel_memberships WHERE user_id = users.id AND chat_channel_id = ?)",
            params.excluded_memberships_channel_id,
          )
      end

      user_search
    end

    def search_groups(params, guardian)
      Group
        .visible_groups(guardian.user)
        .members_visible_groups(guardian.user)
        .includes(users: :user_option)
        .where(
          "groups.name ILIKE :term_like OR groups.full_name ILIKE :term_like",
          term_like: "%#{params.term}%",
        )
        .limit(SEARCH_RESULT_LIMIT)
    end

    def search_category_channels(params, guardian)
      ::Chat::ChannelFetcher.secured_public_channel_search(
        guardian,
        status: :open,
        filter: params.term,
        filter_on_category_name: false,
        match_filter_on_starts_with: false,
        limit: SEARCH_RESULT_LIMIT,
      )
    end

    def search_direct_message_channels(guardian, params, users)
      channels =
        ::Chat::ChannelFetcher.secured_direct_message_channels_search(
          guardian.user.id,
          guardian,
          filter: params.term,
          match_filter_on_starts_with: false,
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
