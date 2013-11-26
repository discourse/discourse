class SessionController < ApplicationController

  skip_before_filter :redirect_to_login_if_required

  def csrf
    render json: {csrf: form_authenticity_token }
  end

  def create
    params.require(:login)
    params.require(:password)
    
    login = params[:login]
    
    ldap = Net::LDAP.new(
      host: "10.5.3.100",
      port: 636,
      encryption: :simple_tls,
      base: "dc=cph, dc=pri")
    ldap.auth "#{login}@cph.pri", params[:password]
    
    # If their password is correct
    if ldap.bind
      
      # Look up the user using their Active Directory email
      entry = ldap.search(filter: Net::LDAP::Filter.eq("sAMAccountName", login)).first
      raise "LDAP record for #{login} does not have 'mail' attribute" unless entry.respond_to?(:mail)
      raise "LDAP record for #{login} does not have 'name' attribute" unless entry.respond_to?(:name)
      
      email = entry.mail.first.downcase
      @user = User.where(email: email).first
      
      # Create a Discourse user if the CPH user doesn't exist
      unless @user
        @user = User.create(email: email, username: login, name: entry.name.first)
      end
      
      # Log in
      log_on_user(@user)
      render_serialized(@user, UserSerializer)
      return
    end
    
    render json: {error: I18n.t("login.incorrect_username_email_or_password")}
  end

  def forgot_password
    params.require(:login)

    user = User.where('username_lower = :username or email = :email', username: params[:login].downcase, email: Email.downcase(params[:login])).first
    if user.present?
      email_token = user.email_tokens.create(email: user.email)
      Jobs.enqueue(:user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
    end
    # always render of so we don't leak information
    render json: {result: "ok"}
  end

  def destroy
    reset_session
    cookies[:_t] = nil
    render nothing: true
  end

end
