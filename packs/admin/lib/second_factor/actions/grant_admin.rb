# frozen_string_literal: true

module SecondFactor::Actions
  class GrantAdmin < Base
    def no_second_factors_enabled!(params)
      user = find_user(params[:user_id])
      AdminConfirmation.new(user, current_user).create_confirmation
      nil
    end

    def second_factor_auth_required!(params)
      user = find_user(params[:user_id])
      description =
        I18n.t("second_factor_auth.actions.grant_admin.description", username: "@#{user.username}")
      {
        callback_params: {
          user_id: user.id,
        },
        redirect_url: admin_user_show_path(id: user.id, username: user.username),
        description: description,
      }
    end

    def second_factor_auth_completed!(callback_params)
      user = find_user(callback_params[:user_id])
      user.grant_admin!
      StaffActionLogger.new(current_user).log_grant_admin(user)
      nil
    end

    private

    def find_user(id)
      user = User.find_by(id: id)
      raise Discourse::NotFound if !user
      guardian.ensure_can_grant_admin!(user)
      user
    end
  end
end
