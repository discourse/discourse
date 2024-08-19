# frozen_string_literal: true

module PageObjects
  module Modals
    class PenalizeUser < PageObjects::Modals::Base
      def initialize(penalty_type)
        @penalty_type = penalty_type
      end

      def similar_users
        modal.all("table tbody tr td:nth-child(2)").map(&:text)
      end

      def modal
        find(".d-modal.#{@penalty_type}-user-modal")
      end
    end
  end
end
