# frozen_string_literal: true

module PageObjects
  module Modals
    class InstallTheme < PageObjects::Modals::Base
      def modal
        find(".admin-install-theme-modal")
      end

      def popular_options
        all(".popular-theme-item")
      end
    end
  end
end
