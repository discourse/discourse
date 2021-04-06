# frozen_string_literal: true

class Admin::ImpersonateController < Admin::AdminController

  def create
    params.require(:username_or_email)

    user = User.find_by_username_or_email(params[:username_or_email])
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    if !authenticate_second_factor
      return render(json: @second_factor_failure_payload)
    end

    log_and_impersonate(user)

    render body: nil
  end

  private

  def authenticate_second_factor
    second_factor_authentication_result = current_user.authenticate_second_factor(params, secure_session)
    if !second_factor_authentication_result.ok
      failure_payload = second_factor_authentication_result.to_h
      if current_user.security_keys_enabled?
        Webauthn.stage_challenge(current_user, secure_session)
        failure_payload.merge!(Webauthn.allowed_credentials(current_user, secure_session))
      end
      @second_factor_failure_payload = failed_json.merge(failure_payload)
      return false
    end

    true
  end

  def log_and_impersonate(user)
    # log impersonate
    StaffActionLogger.new(current_user).log_impersonate(user)

    # Log on as the user
    log_on_user(user, impersonate: true)
  end

end
