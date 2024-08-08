# frozen_string_literal: true

module PageObjects
  module Components
    class Logo < PageObjects::Pages::Base
      SELECTOR = "#site-logo"

      def self.click
        new.find(SELECTOR).click
      end

      def self.hover
        new.find(SELECTOR).hover
      end
    end
  end
end
