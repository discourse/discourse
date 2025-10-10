# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Filter < PageObjects::Components::Base
        attr_reader :parent_locator

        def initialize(parent_locator = nil)
          @parent_locator = parent_locator || locator(".chat-channel")
        end

        def filter_bar
          @filter_bar ||= parent_locator.locator(".chat-channel__filter-bar")
        end

        def toggle
          parent_locator.locator(".c-navbar__filter").click
          self
        end

        def not_visible?
          expect(filter_bar).to be_hidden
        end

        def visible?
          expect(filter_bar).to be_visible
        end

        def fill_in(query)
          filter_bar.locator("input").fill(query)
          self
        end

        def has_no_results?
          toasts = PageObjects::Components::Toasts.new
          toasts.has_error?(I18n.t("js.chat.search.no_results"))
        end

        def has_state?(results: nil, position: nil)
          parent_locator.locator(".chat-channel__filter-position-total", hasText: results) &&
            parent_locator.locator(".chat-channel__filter-position-index", hasText: position)
        end

        def navigate_to_previous_result
          filter_bar.locator(".chat-channel__prev-result").click
          self
        end

        def navigate_to_next_result
          filter_bar.locator(".chat-channel__next-result").click
          self
        end
      end
    end
  end
end
