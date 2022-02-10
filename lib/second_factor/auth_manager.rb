# frozen_string_literal: true

class SecondFactor::AuthManager
  MAX_CHALLENGE_AGE = 5.minutes

  class SecondFactorRequired < StandardError
    attr_reader :nonce

    def initialize(nonce:)
      @nonce = nonce
    end
  end

  attr_reader :allowed_methods

  def self.find_second_factor_challenge(nonce, secure_session)
    challenge_json = secure_session["current_second_factor_auth_challenge"]
    if challenge_json.blank?
      raise SecondFactor::BadChallenge.new(
        "second_factor_auth.challenge_not_found",
        status_code: 404
      )
    end

    challenge = JSON.parse(challenge_json).deep_symbolize_keys
    if challenge[:nonce] != nonce
      raise SecondFactor::BadChallenge.new(
        "second_factor_auth.challenge_not_found",
        status_code: 404
      )
    end

    generated_at = challenge[:generated_at]
    if generated_at < MAX_CHALLENGE_AGE.ago.to_i
      raise SecondFactor::BadChallenge.new(
        "second_factor_auth.challenge_expired",
        status_code: 401
      )
    end
    challenge
  end

  def initialize(current_user, guardian, action)
    @current_user = current_user
    @guardian = guardian
    @action = action
    @allowed_methods = Set.new([
      UserSecondFactor.methods[:totp],
      UserSecondFactor.methods[:security_key],
    ]).freeze
  end

  def allow_backup_codes!
    add_method(UserSecondFactor.methods[:backup_codes])
  end

  def run!(request, params, secure_session)
    if !allowed_methods.any? { |m| @current_user.valid_second_factor_method_for_user?(m) }
      @action.no_second_factors_enabled!(params)
      create_result(:no_second_factor)
    elsif nonce = params[:second_factor_nonce].presence
      verify_second_factor_auth_completed(nonce, secure_session)
      create_result(:second_factor_auth_completed)
    else
      nonce = initiate_second_factor_auth(params, secure_session, request)
      raise SecondFactorRequired.new(nonce: nonce)
    end
  end

  private

  def initiate_second_factor_auth(params, secure_session, request)
    config = @action.second_factor_auth_required!(params)
    nonce = SecureRandom.alphanumeric(32)
    callback_params = config[:callback_params] || {}
    redirect_path = config[:redirect_path] || GlobalPath.path("/")
    challenge = {
      nonce: nonce,
      callback_method: request.request_method,
      callback_path: request.path,
      callback_params: callback_params,
      redirect_path: redirect_path,
      allowed_methods: allowed_methods.to_a,
      generated_at: Time.zone.now.to_i
    }
    secure_session["current_second_factor_auth_challenge"] = challenge.to_json
    nonce
  end

  def verify_second_factor_auth_completed(nonce, secure_session)
    challenge = self.class.find_second_factor_challenge(nonce, secure_session)
    if !challenge[:successful]
      raise SecondFactor::BadChallenge.new(
        "second_factor_auth.challenge_not_completed",
        status_code: 401
      )
    end

    secure_session["current_second_factor_auth_challenge"] = nil
    callback_params = challenge[:callback_params]
    @action.second_factor_auth_completed!(callback_params)
  end

  def add_method(id)
    if !@allowed_methods.include?(id)
      @allowed_methods = Set.new(@allowed_methods)
      @allowed_methods.add(id)
      @allowed_methods.freeze
    end
  end

  def create_result(status)
    SecondFactor::AuthManagerResult.new(status)
  end
end
