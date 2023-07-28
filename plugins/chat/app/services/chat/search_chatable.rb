# frozen_string_literal: true

module Chat
  # Returns a list of chatables (users, category channels, direct message channels) that can be chatted with.
  #
  # @example
  #  Chat::SearchChatable.call(term: "@bob", guardian: guardian)
  #
  class SearchChatable
    include Service::Base

    # @!method call(term:, guardian:)
    #   @param [String] term
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    step :set_mode
    step :clean_term
    step :fetch_memberships
    step :fetch_users
    step :fetch_category_channels
    step :fetch_direct_message_channels

    # @!visibility private
    class Contract
      attribute :term, default: ""
    end

    private

    def set_mode
      context.mode =
        if context.contract.term&.start_with?("#")
          :channel
        elsif context.contract.term&.start_with?("@")
          :user
        else
          :all
        end
    end

    def clean_term(contract:, **)
      context.term = contract.term.downcase&.gsub(/^#+/, "")&.gsub(/^@+/, "")&.strip
    end

    def fetch_memberships(guardian:, **)
      context.memberships = ::Chat::ChannelMembershipManager.all_for_user(guardian.user)
    end

    def fetch_users(guardian:, **)
      return unless guardian.can_create_direct_message?
      return if context.mode == :channel
      context.users = search_users(context.term, guardian)
    end

    def fetch_category_channels(guardian:, **)
      return if context.mode == :user
      return if !SiteSetting.enable_public_channels

      context.category_channels =
        ::Chat::ChannelFetcher.secured_public_channel_search(
          guardian,
          filter_on_category_name: false,
          match_filter_on_starts_with: false,
          filter: context.term,
          status: :open,
          limit: 10,
        )
    end

    def fetch_direct_message_channels(guardian:, **args)
      return if context.mode == :user

      user_ids = nil
      if context.term.length > 0
        user_ids =
          (context.users.nil? ? search_users(context.term, guardian) : context.users).map(&:id)
      end

      channels =
        ::Chat::ChannelFetcher.secured_direct_message_channels_search(
          guardian.user.id,
          guardian,
          limit: 10,
          user_ids: user_ids,
        ) || []

      if user_ids.present? && context.mode == :all
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
      user_search = ::UserSearch.new(term, limit: 10)

      if term.blank?
        user_search.scoped_users.includes(:user_option)
      else
        user_search.search.includes(:user_option)
      end
    end
  end
end
