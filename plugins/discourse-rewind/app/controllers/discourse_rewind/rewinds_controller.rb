# frozen_string_literal: true

module ::DiscourseRewind
  class RewindsController < ::ApplicationController
    requires_login
    requires_plugin PLUGIN_NAME

    def dismiss
      DiscourseRewind::Dismiss.call(service_params) do
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def index
      DiscourseRewind::FetchReports.call(service_params) do
        on_model_not_found(:for_user) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.user_not_found")
        end
        on_model_not_found(:year) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.invalid_year")
        end
        on_model_not_found(:all_reports) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.report_failed")
        end
        on_success do |reports:, total_available:|
          render json: { reports:, total_available: }, status: :ok
        end
      end
    end

    def show
      DiscourseRewind::FetchReport.call(service_params) do
        on_model_not_found(:for_user) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.user_not_found")
        end
        on_model_not_found(:year) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.invalid_year")
        end
        on_model_not_found(:all_reports) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.reports_not_cached")
        end
        on_model_not_found(:report) do
          raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.report_not_found")
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_success { |report:| render json: { report: }, status: :ok }
      end
    end

    def toggle_share
      DiscourseRewind::ToggleShare.call(service_params) do
        on_success do |shared:|
          render json: {
                   shared: guardian.user.reload.user_option.discourse_rewind_share_publicly,
                 },
                 status: :ok
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
