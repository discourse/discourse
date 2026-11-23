# frozen_string_literal: true

# A browser has one pending action. Only the initiating session can verify it,
# and only the original action, scope and target can consume it. Both transitions
# compare the entire record so that an older request cannot undo a replacement.
#
# run! dispatches existing sensitive actions: skip if the action allows it,
# use its no-factor fallback if no allowed factor is enrolled, or start a challenge.
# Login uses start! and complete! explicitly; a provider callback is never a continuation.
class SecondFactor::AuthManager
  MAX_CHALLENGE_AGE = 5.minutes
  COMPLETION_GRACE_PERIOD = 1.minute
  SESSION_KEY = "second_factor_pending_action"

  class SecondFactorRequired < StandardError
    attr_reader :nonce

    def initialize(nonce:)
      @nonce = nonce
    end
  end

  attr_reader :allowed_methods

  def self.find_second_factor_challenge(nonce:, server_session:, request:, current_user:)
    challenge = server_session[SESSION_KEY]
    challenge_not_found! unless challenge && challenge[:nonce] == nonce
    challenge_not_found! unless challenge[:initiator] == initiator(request, current_user)
    challenge_not_found! if current_user && challenge[:target_user_id] != current_user.id
    check_expiry!(challenge)
    challenge
  end

  def self.mark_challenge_successful!(challenge, server_session:)
    check_expiry!(challenge)
    verified =
      challenge.merge(
        successful: true,
        expires_at: challenge.fetch(:expires_at) + COMPLETION_GRACE_PERIOD.to_i,
      )
    unless server_session.compare_and_set(SESSION_KEY, expected: challenge, replacement: verified)
      challenge_not_found!
    end
  end

  def self.initiator(request, user)
    return if !user
    {
      user_id: user.id,
      token_id: request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]&.id,
    }
  end

  def self.check_expiry!(challenge)
    if Time.current.to_i >= challenge.fetch(:expires_at)
      raise SecondFactor::BadChallenge.new("second_factor_auth.challenge_expired", status_code: 401)
    end
  end
  private_class_method :check_expiry!

  def self.challenge_not_found!
    raise SecondFactor::BadChallenge.new("second_factor_auth.challenge_not_found", status_code: 404)
  end

  def initialize(guardian, action, target_user:)
    @current_user = guardian.user
    @target_user = target_user
    @action = action
    @allowed_methods =
      %i[totp security_key passkey].map { |method| UserSecondFactor.methods[method] }.to_set.freeze
  end

  def allow_backup_codes!
    @allowed_methods = (@allowed_methods | [UserSecondFactor.methods[:backup_codes]]).freeze
  end

  def run!(request, params, server_session, nonce: params[:second_factor_nonce].presence)
    if nonce
      challenge =
        self.class.find_second_factor_challenge(
          nonce:,
          server_session:,
          request:,
          current_user: @current_user,
        )
      data = complete!(challenge, server_session)
      create_result(:second_factor_auth_completed, data)
    elsif @action.skip_second_factor_auth?(params)
      data = @action.second_factor_auth_skipped!(params)
      create_result(:second_factor_auth_skipped, data)
    elsif !allowed_methods.any? { |m| @target_user.valid_second_factor_method_for_user?(m) }
      data = @action.no_second_factors_enabled!(params)
      create_result(:no_second_factor, data)
    else
      start!(request, server_session, params:)
    end
  end

  def start!(request, server_session, params: {}, initiator: @current_user)
    config = @action.second_factor_auth_required!(params)
    nonce = SecureRandom.alphanumeric(32)
    callback_params = config[:callback_params] || {}
    challenge = {
      nonce: nonce,
      action: @action.class.name,
      scope: @action.challenge_scope,
      callback_params: callback_params.to_json,
      callback_method: config[:callback_method] || request.request_method,
      callback_path: config[:callback_path] || request.path,
      allowed_methods: allowed_methods.to_a,
      expires_at: MAX_CHALLENGE_AGE.from_now.to_i,
      target_user_id: @target_user.id,
      initiator: self.class.initiator(request, initiator),
    }
    challenge[:description] = config[:description] if config[:description]
    challenge[:redirect_url] = config[:redirect_url] if config[:redirect_url].present?
    # One pending action per browser. A new action supersedes the old one.
    server_session.set(SESSION_KEY, challenge, expires: MAX_CHALLENGE_AGE + COMPLETION_GRACE_PERIOD)
    raise SecondFactorRequired.new(nonce:)
  end

  def complete!(challenge, server_session)
    if challenge[:target_user_id] != @target_user&.id || challenge[:action] != @action.class.name ||
         challenge[:scope] != @action.challenge_scope
      self.class.challenge_not_found!
    end

    if !challenge[:successful]
      raise SecondFactor::BadChallenge.new(
              "second_factor_auth.challenge_not_completed",
              status_code: 401,
            )
    end

    # Only the request that removes this exact verified challenge may perform the action.
    unless server_session.compare_and_set(SESSION_KEY, expected: challenge, replacement: nil)
      self.class.challenge_not_found!
    end
    @action.second_factor_auth_completed!(
      JSON.parse(challenge.fetch(:callback_params), symbolize_names: true),
    )
  end

  private

  def create_result(status, data = nil)
    SecondFactor::AuthManagerResult.new(status, data)
  end
end
