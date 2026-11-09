# frozen_string_literal: true

class DsaNoticesController < ApplicationController
  skip_before_action :check_xhr, only: :index
  skip_before_action :redirect_to_login_if_required, :redirect_to_profile_if_required
  before_action :ensure_enabled

  def index
    respond_to { |format| format.html { render "default/empty" } }
  end

  def verify_email
    Dsa::RequestNoticeVerification.call(
      service_params.merge(options: { ip_address: request.remote_ip }),
    ) do
      on_success { |token:| render json: { token: }, status: :accepted }
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
      on_failure { render_json_error(I18n.t("js.generic_error")) }
    end
  end

  def create
    submission = service_params
    if account_email = Dsa::Notice.verified_account_email(current_user)
      Dsa::NoticeRateLimiter.perform(
        email: account_email,
        ip_address: request.remote_ip,
        user_id: current_user.id,
      )
      submission = submission.deep_merge(params: { notice: { email: account_email } })
    end

    Dsa::SubmitNotice.call(submission) do
      on_success { |notice:| render json: { reference: notice.reference }, status: :created }
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
      on_model_not_found(:verification) do
        render_json_error(
          I18n.t("dsa_notice.verification_invalid"),
          status: 422,
          type: "verification_required",
        )
      end
      on_failure { render_json_error(I18n.t("js.generic_error")) }
    end
  end

  def verify_code
    Dsa::VerifyNoticeEmail.call(service_params) do
      on_success { render json: success_json }
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
      on_model_not_found(:verification) do |failure|
        raise failure.exception if failure.exception
        render_json_error(I18n.t("dsa_notice.verification_invalid"), status: 422)
      end
      on_failure { render_json_error(I18n.t("js.generic_error")) }
    end
  end

  private

  def ensure_enabled
    raise Discourse::NotFound unless SiteSetting.dsa_reporting_enabled
  end
end
