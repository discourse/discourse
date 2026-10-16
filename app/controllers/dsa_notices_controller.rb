# frozen_string_literal: true

class DsaNoticesController < ApplicationController
  skip_before_action :check_xhr, only: :index
  skip_before_action :redirect_to_login_if_required, :redirect_to_profile_if_required
  before_action :ensure_enabled, only: :index

  def index
    respond_to { |format| format.html { render "default/empty" } }
  end

  def create
    Dsa::SubmitNotice.call(service_params.merge(options: { ip_address: request.remote_ip })) do
      on_success do |notice:|
        render json: {
                 reference: notice.reference,
                 contact: notice.email.present?,
               },
               status: :created
      end
      on_failed_policy(:enabled) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
      on_failed_policy(:matches_submission) do
        render_json_error(I18n.t("dsa_notice.submission_changed"), status: 409)
      end
      on_model_not_found(:notice) do |failure|
        if failure.exception
          Discourse.warn_exception(
            failure.exception,
            message: "Illegal content notice could not be saved",
          )
        end
        render_json_error(I18n.t("dsa_notice.failed"), status: 503)
      end
      on_exceptions do |exception|
        Discourse.warn_exception(
          exception,
          message: "Illegal content notice notifications could not be queued",
        )
        render_json_error(I18n.t("dsa_notice.retry_submission"), status: 503)
      end
      on_failure { render_json_error(I18n.t("dsa_notice.failed"), status: 422) }
    end
  end

  private

  def ensure_enabled
    raise Discourse::NotFound unless SiteSetting.dsa_reporting_enabled
  end
end
