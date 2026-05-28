# frozen_string_literal: true

module PageObjects
  module Modals
    class DeleteThemesConfirm < PageObjects::Pages::Base
      def has_theme?(name)
        has_css?(".modal li", text: name)
      end

      def confirm
        find(".d-modal__footer .btn-primary").click
      end
    end
  end
end
