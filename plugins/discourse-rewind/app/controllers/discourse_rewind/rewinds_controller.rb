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
        on_model_not_found(:for_user) { raise_not_found("user_not_found") }
        on_model_not_found(:year) { raise_not_found("invalid_year") }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_success { |reports:, total_available:| render json: { reports:, total_available: } }
      end
    end

    def toggle_share
      DiscourseRewind::ToggleShare.call(service_params) do
        on_success { |shared:| render json: { shared: } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:user_not_hiding_profile) do
          render_json_error(
            I18n.t("discourse_rewind.cannot_share_when_profile_hidden"),
            status: :bad_request,
          )
        end
      end
    end

    private

    def raise_not_found(key)
      raise Discourse::NotFound.new(nil, custom_message: "discourse_rewind.#{key}")
    end
  end
end
