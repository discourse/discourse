# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Filter < PageObjects::Components::Base
        def filter_bar
          locator(".chat-channel__filter-bar")
        end

        def available?
          filter = locator(".c-navbar__filter")
          filter.wait_for(state: "visible")
          filter.visible?
        end

        def not_available?
          filter = locator(".c-navbar__filter")
          filter.wait_for(state: "hidden")
          filter.hidden?
        end

        def toggle
          find(".c-navbar__filter").click
          self
        end

        def not_visible?
          filter_bar.wait_for(state: "hidden")
          filter_bar.hidden?
        end

        def visible?
          filter_bar.wait_for(state: "visible")
          filter_bar.visible?
        end

        def fill_in(query)
          filter_bar.locator("input").fill(query)
          self
        end

        def clear
          filter_bar.locator(".filter-input-clear-btn").click
          self
        end

        def has_no_state?
          has_no_css?(".chat-channel__filter-position")
        end

        def has_no_results?
          has_css?(".alert.alert-info", text: I18n.t("js.chat.search.no_results"))
        end

        def has_state?(results:, position:)
          has_css?(".chat-channel__filter-position-total", exact_text: results.to_s) &&
            has_css?(".chat-channel__filter-position-index", exact_text: position.to_s)
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
