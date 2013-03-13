class EmailController < ApplicationController
  skip_before_filter :check_xhr
  layout 'no_js'

  before_filter :ensure_logged_in, only: :preferences_redirect

  def preferences_redirect
    redirect_to(email_preferences_path(current_user.username_lower))
  end

  def unsubscribe
    @user = User.find_by_temporary_key(params[:key])

    # Don't allow the use of a key while logged in as a different user
    @user = nil if current_user.present? && (@user != current_user)

    if @user.present?
      @user.update_column(:email_digests, false)
    else
      @not_found = true
    end
  end

  def resubscribe
    @user = User.find_by_temporary_key(params[:key])
    raise Discourse::NotFound unless @user.present?
    @user.update_column(:email_digests, true)
  end

end
