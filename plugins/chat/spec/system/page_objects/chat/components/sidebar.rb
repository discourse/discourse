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

        def has_no_dm_section?
          has_no_selector?(".sidebar-section[data-section-name='chat-dms']")
        end

        NEW_START_DM_SELECTOR = ".sidebar-section-link[data-link-name='new-chat-dm']"

        def has_no_start_new_dm?
          has_no_selector?(NEW_START_DM_SELECTOR)
        end

        def has_start_new_dm?
          has_selector?(NEW_START_DM_SELECTOR)
        end

        def click_start_new_dm
          find(NEW_START_DM_SELECTOR).click
        end
      end
    end
  end
end
