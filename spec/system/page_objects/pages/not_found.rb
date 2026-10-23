# frozen_string_literal: true

module PageObjects
  module Pages
    class NotFound < PageObjects::Pages::Base
      def visible?
        has_css?("div.page-not-found")
      end
    end
  end
end
