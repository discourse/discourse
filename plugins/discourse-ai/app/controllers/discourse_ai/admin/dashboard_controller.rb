# frozen_string_literal: true

module DiscourseAi
  module Admin
    class DashboardController < ::Admin::StaffController
      requires_plugin DiscourseAi::PLUGIN_NAME

      def sentiment
      end
    end
  end
end
