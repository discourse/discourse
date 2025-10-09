# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Filter < PageObjects::Components::Base
        attr_reader :parent_locator

        def initialize(parent_locator = nil)
          @parent_locator = parent_locator || locator(".chat-channel")
        end

        # def visible?
        #   parent_locator.locator(".chat-channel__filter-bar").visible?
        # end

        # def not_visible?
        #   !visible?
        # end

        # def input
        #   parent_locator.locator(".chat-channel__filter-bar input")
        # end

        # def fill_in(query)
        #   parent_locator.locator(".chat-channel__filter-bar input").fill(query)
        # end

        # def clear
        #   parent_locator.locator(".chat-channel__filter-bar input").clear
        # end

        # def has_query?(expected)
        #   parent_locator.locator(".chat-channel__filter-bar input").input_value == expected
        # end

        # def results_count
        #   text = parent_locator.locator(".chat-channel__filter-bar span").text_content
        #   text.split("/").last.to_i
        # end

        # def current_result_position
        #   text = parent_locator.locator(".chat-channel__filter-bar span").text_content
        #   text.split("/").first.to_i
        # end

        # def navigate_to_previous_result
        #   parent_locator.locator(
        #     ".chat-channel__filter-bar .btn-small[data-icon='chevron-up']",
        #   ).click
        # end

        # def navigate_to_next_result
        #   parent_locator.locator(
        #     ".chat-channel__filter-bar .btn-small[data-icon='chevron-down']",
        #   ).click
        # end

        # def close
        #   parent_locator.locator(".chat-channel__filter-bar .btn-primary").click
        # end

        # def has_results?
        #   parent_locator.locator(".chat-channel__filter-bar span").count > 0
        # end

        # def has_no_results?
        #   !has_results?
        # end
      end
    end
  end
end
