# frozen_string_literal: true

class Admin::ImpersonateController < Admin::AdminController
  skip_before_action :ensure_admin, only: :destroy

  def create
    params.require(:username_or_email)

    user = User.find_by_username_or_email(params[:username_or_email])
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    StaffActionLogger.new(current_user).log_impersonate(user)

    if UpcomingChanges.enabled_for_user?(:impersonate_without_logout, current_user)
      raise Discourse::InvalidAccess if current_user.is_impersonating

      start_impersonating_user(user)
    else
      log_on_user(user, impersonate: true)
    end

    render body: nil
  end

  def destroy
    unless UpcomingChanges.enabled_for_user?(:impersonate_without_logout, current_user)
      raise Discourse::NotFound
    end

    raise Discourse::InvalidAccess unless current_user.is_impersonating

    impersonated_user = current_user
    stop_impersonating_user
    StaffActionLogger.new(current_user).log_stop_impersonation(impersonated_user)

    render body: nil
  end
end
