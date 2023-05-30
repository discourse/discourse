# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatBrowse < PageObjects::Pages::Base
      def component
        find(".chat-browse-view")
      end

      def has_finished_loading?
        component.has_css?(".loading-container .spinner", wait: 0)
        component.has_no_css?(".loading-container .spinner")
      end

      def search(query)
        component.find(".dc-filter-input").fill_in(with: query)
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
