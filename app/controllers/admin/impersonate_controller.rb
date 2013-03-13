class Admin::ImpersonateController < Admin::AdminController

  def create
    requires_parameters(:username_or_email)

    user = User.find_by_username_or_email(params[:username_or_email]).first

    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    # Log on as the user
    log_on_user(user)

    render nothing: true
  end

end
