# frozen_string_literal: true

module PageObjects
  module Components
    class Logo < PageObjects::Pages::Base
      SELECTOR = "#site-logo"

      def click
        find(".d-header .title a").click
      end

      def hover
        find(SELECTOR).hover
      end
    end
  end
end
