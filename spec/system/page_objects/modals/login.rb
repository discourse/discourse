# frozen_string_literal: true

module PageObjects
  module Modals
    class Login < PageObjects::Modals::Base
      def open?
        super && has_css?(".login-modal")
      end
    end
  end
end
