# frozen_string_literal: true

module Chat
  # Returns a list of chatables (users, category channels, direct message channels) that can be chatted with.
  #
  # @example
  #  Chat::SearchChatables.call(term: "@bob", guardian: guardian)
  #
  class SearchChatable
    include Service::Base

    # @!method call(term:, guardian:)
    #   @param [String] term
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    step :fetch_users
    step :fetch_category_channels
    step :fetch_direct_message_channels

    # @!visibility private
    class Contract
      attribute :term, default: ""
    end

    private

    def fetch_users(contract:, guardian:, **)
      return if contract.term&.start_with?("#")

      context.users = search_user(contract.term, guardian)
    end

    def fetch_category_channels(contract:, guardian:, **)
      term = contract.term&.downcase&.gsub(/^#+/, "").strip
      return if term&.start_with?("@")

      context.category_channels =
        Chat::ChannelFetcher.secured_public_channels(
          guardian,
          filter: term,
          status: :open,
          limit: 10,
        )
    end

    def fetch_direct_message_channels(contract:, guardian:, **args)
      return if contract.term == "#"
      return if contract.term&.start_with?("@")

      user_ids =
        (context.users.nil? ? search_user(contract.term, guardian) : context.users).map(&:id)
      return if user_ids.blank?

      context.direct_message_channels =
        Chat::ChannelFetcher.secured_direct_message_channels_search(
          guardian.user.id,
          guardian,
          limit: 10,
          user_ids: user_ids,
        )
    end

    def default_user_scope(guardian)
      users =
        User
          .strict_loading
          .includes(:user_option, :groups, :user_status)
          .where(active: true, staged: false)
          .not_suspended
      users = users.where(approved: true) if SiteSetting.must_approve_users?
      users = users.limit(10)
      users
    end

    def search_user(term, guardian)
      if term.blank? || term == "@"
        return default_user_scope(guardian).order("last_seen_at DESC NULLS LAST")
      end

      term = term.downcase.gsub(/^#+/, "").gsub(/^@+/, "").strip
      term_like = term.gsub("_", "\\_") + "%"

      if SiteSetting.enable_names? && term !~ /[_\.-]/
        query = Search.ts_query(term: term, ts_config: "simple")
        order = DB.sql_fragment("CASE WHEN username_lower LIKE ? THEN 0 ELSE 1 END ASC", term_like)

        default_user_scope(guardian)
          .includes(:user_search_data)
          .references(:user_search_data)
          .where("user_search_data.search_data @@ #{query}")
          .order(order)
      else
        default_user_scope(guardian).where("username_lower LIKE :term_like", term_like: term_like)
      end
    end
  end
end
