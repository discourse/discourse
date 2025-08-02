# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ChannelsIndex < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".c-drawer-routes.--channels"

        def initialize(context = nil)
          @context = context
        end

        def component
          return find(SELECTOR) if !@context
          find(context).find(SELECTOR)
        end

        def open_browse
          component.find(".open-browse-page-btn").click
        end

        def open_channel(channel)
          component.find("#{channel_row_selector(channel)}").click
        end

        def channel_row_selector(channel)
          ".chat-channel-row[data-chat-channel-id='#{channel.id}']"
        end

        def has_channel?(channel)
          has_css?(channel_row_selector(channel))
        end

        def has_no_channel?(channel)
          has_no_css?(channel_row_selector(channel))
        end

        def has_unread_channel?(
          channel,
          count: nil,
          urgent: false,
          wait: Capybara.default_max_wait_time
        )
          unread_indicator_selector =
            "#{channel_row_selector(channel)} .chat-channel-unread-indicator"

          unread_indicator_selector += ".-urgent" if urgent

          has_css?(unread_indicator_selector) &&
            if count
              has_css?(
                "#{unread_indicator_selector} .chat-channel-unread-indicator__number",
                text: count,
              )
            else
              true
            end
        end

        def has_no_unread_channel?(channel)
          has_no_css?("#{channel_row_selector(channel)} .chat-channel-unread-indicator")
        end
      end
    end
  end
end
