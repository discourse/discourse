class Admin::ImpersonateController < Admin::AdminController

  def create
    requires_parameters(:username_or_email)

    user = User.where(['username_lower = lower(?) or lower(email) = lower(?) or lower(name) = lower(?)', 
                        params[:username_or_email], 
                        params[:username_or_email],
                        params[:username_or_email]]).first
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    # Log on as the user
    log_on_user(user)

    render nothing: true
  end  

end
