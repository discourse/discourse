# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatBrowse < PageObjects::Pages::Base
      SELECTOR = ".c-routes.--browse"

      def initialize(context = SELECTOR)
        @context = context
      end

      def component
        find("#{@context} .chat-browse-view")
      end

      def change_status(status = "all")
        component.find(".chat-browse-view__filter.-#{status}").click
        has_finished_loading?
      end

      def has_finished_loading?
        component.has_css?(".loading-container .spinner", wait: 0)
        component.has_no_css?(".loading-container .spinner")
      end

      def search(query)
        component.find(".filter-input").fill_in(with: query)
        component.has_css?(".loading-container .spinner", wait: 0)
        component.has_no_css?(".loading-container .spinner")
      end

      def has_channel?(name: nil)
        component.has_content?(name)
      end

      def has_no_channel?(name: nil)
        component.has_no_content?(name)
      end
    end
  end
end
