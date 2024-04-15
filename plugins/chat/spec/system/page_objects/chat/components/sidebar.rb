# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Sidebar < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = "#d-sidebar"

        def component
          page.find(SELECTOR)
        end

        def has_direct_message_channel?(channel, **args)
          channel_selector = direct_message_channel_selector(channel, **args)
          predicate = component.has_css?(channel_selector)

          if args[:unread]
            predicate &&
              component.has_css?("#{channel_selector} .sidebar-section-link-suffix.icon.unread")
          elsif args[:mention]
            predicate &&
              component.has_css?("#{channel_selector} .sidebar-section-link-suffix.icon.urgent")
          else
            predicate &&
              component.has_no_css?("#{channel_selector} .sidebar-section-link-suffix.icon")
          end
        end

        def has_no_direct_message_channel?(channel, **args)
          component.has_no_css?(direct_message_channel_selector(channel, **args))
        end

        def direct_message_channel_selector(channel, **args)
          selector = "#sidebar-section-content-chat-dms"
          selector += " .sidebar-section-link.channel-#{channel.id}"
          selector
        end
      end
    end
  end
end
