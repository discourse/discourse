class SecondFactorController < ApplicationController

  def create
    RateLimiter.new(nil, "login-hr-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_hour, 1.hour).performed!
    RateLimiter.new(nil, "login-min-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_minute, 1.minute).performed!
    if user = User.find_by_username_or_email(params[:login])
      unless user.confirm_password?(params[:password])
        return invalid_credentials
      end
      qrcode = RQRCode::QRCode.new(SecondFactorHelper.provisioning_uri(user))
      qrcode_svg = qrcode.as_svg(
        offset: 0,
        color: '000',
        shape_rendering: 'crispEdges',
        module_size: 4
      )
      render json: { key: user.user_second_factor.data, qr: qrcode_svg }
    end
  end

  def update
    params.require(:token)
    user = fetch_user_from_params
    unless SecondFactorHelper.authenticate(user, params[:token])
      RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
      render json: { error: I18n.t("login.invalid_second_factor_code") }
      return
    end
    if params[:enable] == "true"
      SecondFactorHelper.create_totp(user)
      user.user_second_factor.enabled = true
      user.user_second_factor.save!
      return render json: { result: "ok", action: "enabled" }
    else
      user.user_second_factor.delete
      Jobs.enqueue(
        :critical_user_email,
        type: :account_second_factor_disabled,
        user_id: user.id
      )
      return render json: { result: "ok", action: "disabled" }
    end
  end

  private

  def invalid_credentials
    render json: { error: I18n.t("login.incorrect_username_email_or_password") }
  end

end
