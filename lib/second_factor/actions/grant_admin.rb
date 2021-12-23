# frozen_string_literal: true

module SecondFactor::Actions
  class GrantAdmin < Base
    include Rails.application.routes.url_helpers

    def initialize(params, current_user, guardian)
      @user = User.find_by(id: params[:user_id])
      raise Discourse::NotFound if !@user
      @current_user = current_user
      @guardian = guardian
    end

    def no_second_factors_enabled!
      @guardian.ensure_can_grant_admin!(@user)
      AdminConfirmation.new(@user, @current_user).create_confirmation
    end

    def second_factor_auth_required!
      @guardian.ensure_can_grant_admin!(@user)
      {
        callback_params: { user_id: @user.id },
        redirect_path: admin_user_show_path(id: @user.id, username: @user.username)
      }
    end

    def second_factor_auth_successful!
      @guardian.ensure_can_grant_admin!(@user)
      @user.grant_admin!
      StaffActionLogger.new(@current_user).log_grant_admin(@user)
    end
  end
end
