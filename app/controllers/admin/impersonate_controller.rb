# frozen_string_literal: true

class Admin::ImpersonateController < Admin::AdminController
  skip_before_action :ensure_admin, only: :destroy

  def create
    params.require(:username_or_email)

    user = User.find_by_username_or_email(params[:username_or_email])
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    # log impersonate
    StaffActionLogger.new(current_user).log_impersonate(user)

    if SiteSetting.experimental_impersonation
      raise Discourse::InvalidAccess if current_user.is_impersonating

      start_impersonating_user(user)
    else
      # Log on as the user
      log_on_user(user, impersonate: true)
    end

    render body: nil
  end

  def destroy
    raise Discourse::NotFound if !SiteSetting.experimental_impersonation
    raise Discourse::InvalidAccess if !current_user.is_impersonating

    stop_impersonating_user

    render body: nil
  end
end
