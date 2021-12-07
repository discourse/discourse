# frozen_string_literal: true

class SecondFactorVerificationManager
  SecondFactorAuthConfig = Struct.new(:callback_params, :redirect_path)

  class SecondFactorRequired < StandardError
    attr_reader :nonce

    def initialize(nonce:)
      @nonce = nonce
    end
  end

  attr_reader :allowed_methods

  def initialize(current_user)
    @current_user = current_user
    @allowed_methods = Set.new([
      UserSecondFactor.methods[:totp],
      UserSecondFactor.methods[:security_key],
    ]).freeze
  end

  def allow_backup_codes!
    add_method(UserSecondFactor.methods[:backup_codes])
  end

  def on_second_factor_auth_successful(&block)
    @on_second_factor_auth_successful = block
  end

  def on_second_factor_auth_required(&block)
    @on_second_factor_auth_required = block
  end

  def on_no_second_factors_enabled(&block)
    @on_no_second_factors_enabled = block
  end

  def run!(request, params, secure_session)
    if !allowed_methods.any? { |m| @current_user.valid_second_factor_method_for_user?(m) }
      @on_no_second_factors_enabled.call
    elsif nonce = params[:second_factor_nonce].presence
      second_factor_auth_successful(nonce, secure_session)
    else
      initiate_second_factor_auth(secure_session, request)
    end
  end

  private

  def initiate_second_factor_auth(secure_session, request)
    config = SecondFactorAuthConfig.new
    @on_second_factor_auth_required.call(config)
    nonce = SecureRandom.alphanumeric(32)
    callback_params = config.callback_params || {}
    # TODO: subfolder support??
    redirect_path = config.redirect_path || "/"
    challenge = {
      nonce: nonce,
      callback_method: request.method,
      callback_path: request.path,
      callback_params: callback_params,
      redirect_path: redirect_path,
      allowed_methods: allowed_methods.to_a
    }
    secure_session.set(
      "current_second_factor_auth_challenge",
      challenge.to_json,
      expires: 5.minutes
    )
    raise SecondFactorRequired.new(nonce: nonce)
  end

  def second_factor_auth_successful(nonce, secure_session)
    json = secure_session["current_second_factor_auth_challenge"]
    raise Discourse::InvalidAccess.new if json.blank?

    challenge = JSON.parse(json).deep_symbolize_keys
    if challenge[:nonce] != nonce
      raise Discourse::InvalidAccess.new
    end
    if !challenge[:successful]
      raise Discourse::InvalidAccess.new
    end
    secure_session["current_second_factor_auth_challenge"] = nil
    callback_params = challenge[:callback_params]
    @on_second_factor_auth_successful.call(callback_params)
  end

  def add_method(id)
    if !@allowed_methods.include?(id)
      @allowed_methods = Set.new(@allowed_methods)
      @allowed_methods.add(id)
      @allowed_methods.freeze
    end
  end
end
