# frozen_string_literal: true

class FinishInstallationController < ApplicationController
  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required
  layout "finish_installation"

  before_action :ensure_no_admins, except: %w[confirm_email resend_email]

  def index
    @setting_up_discourse_id = ENV["DISCOURSE_SKIP_EMAIL_SETUP"] == "1"

    setup_discourse_id if @setting_up_discourse_id
  end

  def register
    @allowed_emails = find_allowed_emails

    @user = User.new
    if request.post?
      email = params[:email].strip
      raise Discourse::InvalidParameters.new if @allowed_emails.exclude?(email)

      if existing_user = User.find_by_email(email)
        @user = existing_user
        send_signup_email
        return redirect_confirm(email)
      end

      @user.email = email
      @user.username = params[:username]
      @user.password = params[:password]
      @user.password_required!

      if @user.save
        @user.change_trust_level!(1) if @user.trust_level < 1
        send_signup_email
        redirect_confirm(@user.email)
      end
    end
  end

  def confirm_email
    @email = session[:registered_email]
  end

  def resend_email
    @email = session[:registered_email]
    @user = User.find_by_email(@email)
    send_signup_email if @user.present?
  end

  protected

  def send_signup_email
    return if @user.active && @user.email_confirmed?

    email_token = @user.email_tokens.create!(email: @user.email, scope: EmailToken.scopes[:signup])
    EmailToken.enqueue_signup_email(email_token)
  end

  def redirect_confirm(email)
    session[:registered_email] = email
    redirect_to(finish_installation_confirm_email_path)
  end

  def find_allowed_emails
    unless GlobalSetting.respond_to?(:developer_emails) && GlobalSetting.developer_emails.present?
      return []
    end
    GlobalSetting.developer_emails.split(",").map(&:strip)
  end

  def setup_discourse_id
    begin
      SiteSetting.enable_discourse_id = true
      SiteSetting.enable_local_logins = false
      @discourse_id_enabled = true
      @discourse_id_error = nil

      create_admin_users
    rescue StandardError => e
      @discourse_id_enabled = false
      @discourse_id_error = e.message
    end
  end

  def create_admin_users
    allowed_emails = find_allowed_emails
    if allowed_emails.empty?
      raise StandardError.new("No allowed emails configured for Discourse ID setup.")
    end

    allowed_emails.each do |email|
      next if User.find_by_email(email)

      username = UserNameSuggester.suggest(email)

      user =
        User.new(
          email: email,
          username: username,
          # no password needed, users will login via Discourse ID
          active: false, # will be activated upon first login
          admin: true,
          trust_level: TrustLevel[4],
        )
      user.save!(validate: false)
      Group.refresh_automatic_groups!(:staff, :admins)
    end
  end

  def ensure_no_admins
    raise Discourse::InvalidAccess.new unless SiteSetting.has_login_hint?
  end
end
