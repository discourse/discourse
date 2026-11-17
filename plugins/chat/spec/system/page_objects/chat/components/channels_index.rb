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

        def show_all_channels
          component.find(".empty-state__cta .btn").click
        end

        def toggle_channel_filter
          component.find(".chat-channel-list-filter-toggle").click
        end

        def open_browse
          open_channel_list_options.option('[data-menu-option-id="browseChannels"]').click
        end

        def open_channel_list_options
          trigger = component.find(".chat-channel-list-options-button")
          trigger.click
          PageObjects::Components::DMenu.new(trigger, "chat-channel-list-options-menu")
        end

        def set_channel_sort(sort)
          menu = open_channel_list_options
          sort_trigger = menu.option('[data-menu-option-id="sortChannels"]')
          sort_trigger.click
          submenu = PageObjects::Components::DMenu.new(sort_trigger, "chat-channel-list-sort-menu")
          submenu.option(%([data-menu-option-id="#{sort}"])).click
        end

        def set_channel_filter(filter)
          menu = open_channel_list_options
          filter_trigger = menu.option('[data-menu-option-id="filterChannels"]')
          filter_trigger.click
          submenu =
            PageObjects::Components::DMenu.new(filter_trigger, "chat-channel-list-filter-menu")
          submenu.option(%([data-menu-option-id="#{filter}"])).click
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

        def has_no_channel_list_options_button?
          has_no_css?(".chat-channel-list-options-button")
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
