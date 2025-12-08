# frozen_string_literal: true

module ::DiscourseRewind
  class RewindsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    requires_login

    def show
      DiscourseRewind::FetchReports.call(service_params) do
        on_model_not_found(:year) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.invalid_year")
        end
        on_model_not_found(:reports) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.report_failed")
        end
        on_success { |reports:| render json: MultiJson.dump(reports), status: :ok }
      end
    end
  end
end
