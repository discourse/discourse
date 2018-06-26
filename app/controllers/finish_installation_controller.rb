class FinishInstallationController < ApplicationController
  skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required
  layout 'finish_installation'

  before_action :ensure_no_admins, except: ['confirm_email', 'resend_email']

  def index
  end

  def register
    @allowed_emails = find_allowed_emails

    @user = User.new
    if request.post?
      email = params[:email].strip
      raise Discourse::InvalidParameters.new unless @allowed_emails.include?(email)

      return redirect_confirm(email) if UserEmail.where("lower(email) = ?", email).exists?

      @user.email = email
      @user.username = params[:username]
      @user.password = params[:password]
      @user.password_required!

      if @user.save
        @email_token = @user.email_tokens.unconfirmed.active.first
        Jobs.enqueue(:critical_user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
        return redirect_confirm(@user.email)
      end

    end
  end

  def confirm_email
    @email = session[:registered_email]
  end

  def resend_email
    @email = session[:registered_email]
    @user = User.find_by_email(@email)
    if @user.present?
      @email_token = @user.email_tokens.unconfirmed.active.first
      if @email_token.present?
        Jobs.enqueue(:critical_user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
      end
    end
  end

  protected

  def redirect_confirm(email)
    session[:registered_email] = email
    redirect_to(finish_installation_confirm_email_path)
  end

  def find_allowed_emails
    return [] unless GlobalSetting.respond_to?(:developer_emails) && GlobalSetting.developer_emails.present?
    GlobalSetting.developer_emails.split(",").map(&:strip)
  end

  def ensure_no_admins
    preload_anonymous_data
    raise Discourse::InvalidAccess.new unless SiteSetting.has_login_hint?
  end
end
