# frozen_string_literal: true

module DiscourseWorkflows
  class StatsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Stats::Summary.call(service_params) do |result|
        on_success { |stats:| render json: stats }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def show
      DiscourseWorkflows::Stats::Summary.call(service_params) do |result|
        on_success { |stats:| render json: stats }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
