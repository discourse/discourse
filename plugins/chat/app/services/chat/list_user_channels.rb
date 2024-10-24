# frozen_string_literal: true

module Chat
  # List of the channels a user is tracking
  #
  # @example
  #  Chat::ListUserChannels.call(guardian:)
  #
  class ListUserChannels
    include Service::Base

    # @!method self.call(guardian:)
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    model :structured
    step :inject_unread_thread_overview
    model :post_allowed_category_ids, optional: true

    private

    def fetch_structured(guardian:)
      ::Chat::ChannelFetcher.structured(guardian)
    end

    def inject_unread_thread_overview(structured:, guardian:)
      structured[:unread_thread_overview] = ::Chat::TrackingStateReportQuery.call(
        guardian: guardian,
        channel_ids: structured[:public_channels].map(&:id),
        include_threads: true,
        include_read: false,
        include_last_reply_details: true,
      ).thread_unread_overview_by_channel
    end

    def fetch_post_allowed_category_ids(guardian:, structured:)
      ::Category
        .post_create_allowed(guardian)
        .where(id: structured[:public_channels].map { |c| c.chatable_id })
        .pluck(:id)
    end
  end
end
