class EmailController < ApplicationController
  skip_before_filter :check_xhr, :preload_json
  layout 'no_ember'

  before_filter :ensure_logged_in, only: :preferences_redirect
  skip_before_filter :redirect_to_login_if_required

  def preferences_redirect
    redirect_to(email_preferences_path(current_user.username_lower))
  end

  def unsubscribe
    @user = DigestUnsubscribeKey.user_for_key(params[:key])

    # Don't allow the use of a key while logged in as a different user
    if current_user.present? && (@user != current_user)
      @different_user = true
      return
    end

    if @user.blank?
      @not_found = true
      return
    end

    @user.update_column(:email_digests, false)
    @success = true
  end

  def resubscribe
    @user = DigestUnsubscribeKey.user_for_key(params[:key])
    raise Discourse::NotFound unless @user.present?
    @user.update_column(:email_digests, true)
  end

end
