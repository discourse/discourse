# frozen_string_literal: true

module DiscourseAi
  module SuperAdmin
    class DashboardController < ::SuperAdmin::StaffController
      requires_plugin PLUGIN_NAME

      def sentiment
      end
    end
  end
end
