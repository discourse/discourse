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
    step :fetch_memberships
    step :fetch_users
    step :fetch_category_channels
    step :fetch_direct_message_channels

    # @!visibility private
    class Contract
      attribute :term, default: ""
    end

    private

    def fetch_memberships(guardian:, **)
      context.memberships = Chat::ChannelMembershipManager.all_for_user(guardian.user)
    end

    def fetch_users(contract:, guardian:, **)
      return if contract.term&.start_with?("#")

      context.users = search_users(contract.term, guardian)
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

      exclude_1_to_1_channels = !contract.term&.start_with?("#")

      user_ids =
        (context.users.nil? ? search_users(contract.term, guardian) : context.users).map(&:id)
      return if user_ids.blank?

      channels =
        Chat::ChannelFetcher.secured_direct_message_channels_search(
          guardian.user.id,
          guardian,
          limit: 10,
          user_ids: user_ids,
        ) || []

      if exclude_1_to_1_channels
        channels =
          channels.reject do |channel|
            channel_user_ids = channel.allowed_user_ids - [guardian.user.id]
            channel.allowed_user_ids.length == 1 &&
              user_ids.include?(channel.allowed_user_ids.first) ||
              channel_user_ids.length == 1 && user_ids.include?(channel_user_ids.first)
          end
      end

      context.direct_message_channels = channels
    end

    def search_users(term, guardian)
      term = term.downcase.gsub(/^#+/, "").gsub(/^@+/, "").strip
      UserSearch.new(term, limit: 10).search.includes(:user_option)
    end
  end
end
