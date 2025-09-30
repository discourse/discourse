# frozen_string_literal: true

module DiscourseWebauthn
  ACCEPTABLE_REGISTRATION_TYPE = "webauthn.create"
  ACCEPTABLE_AUTHENTICATION_TYPE = "webauthn.get"

  # -7   - ES256
  # -257 - RS256 (Windows Hello supported alg.)
  SUPPORTED_ALGORITHMS = COSE::Algorithm.registered_algorithm_ids.freeze
  VALID_ATTESTATION_FORMATS = %w[none packed fido-u2f].freeze
  CHALLENGE_EXPIRY = 5.minutes

  class SecurityKeyError < StandardError
  end

  class InvalidOriginError < SecurityKeyError
  end

  class InvalidRelyingPartyIdError < SecurityKeyError
  end

  class UserVerificationError < SecurityKeyError
  end

  class UserPresenceError < SecurityKeyError
  end

  class ChallengeMismatchError < SecurityKeyError
  end

  class InvalidTypeError < SecurityKeyError
  end

  class UnsupportedPublicKeyAlgorithmError < SecurityKeyError
  end

  class UnsupportedAttestationFormatError < SecurityKeyError
  end

  class CredentialIdInUseError < SecurityKeyError
  end

  class MalformedAttestationError < SecurityKeyError
  end

  class KeyNotFoundError < SecurityKeyError
  end

  class MalformedPublicKeyCredentialError < SecurityKeyError
  end

  class OwnershipError < SecurityKeyError
  end

  class PublicKeyError < SecurityKeyError
  end

  class UnknownCOSEAlgorithmError < SecurityKeyError
  end

  ##
  # Usage:
  #
  # These methods should be used in controllers where we
  # are challenging the user that has a security key, and
  # they must respond with a valid webauthn response and
  # credentials.
  #
  # @param user [User] the user to stage the challenge for
  # @param server_session [ServerSession] the session to store the challenge in
  def self.stage_challenge(user, server_session)
    ::DiscourseWebauthn::ChallengeGenerator.generate.commit_to_session(
      server_session,
      user,
      expires: CHALLENGE_EXPIRY,
    )
  end

  ##
  # Clears the challenge from the user's server session.
  #
  # @param user [User] the user to clear the challenge for
  # @param server_session [ServerSession] the session to clear the challenge from
  def self.clear_challenge(user, server_session)
    server_session.delete(session_challenge_key(user))
  end

  def self.allowed_credentials(user, server_session)
    return {} if !user.security_keys_enabled?

    {
      allowed_credential_ids: user.second_factor_security_key_credential_ids,
      challenge: challenge(user, server_session),
    }
  end

  def self.challenge(user, server_session)
    server_session[session_challenge_key(user)]
  end

  def self.rp_id
    Rails.env.production? ? Discourse.current_hostname : "localhost"
  end

  def self.origin
    case Rails.env
    when "development"
      # defaults to the Ember CLI local port
      # you might need to change this and the rp_id above
      # if you are using a non-default port/hostname locally
      "http://localhost:4200"
    else
      Discourse.base_url_no_prefix
    end
  end

  def self.rp_name
    SiteSetting.title
  end

  def self.session_challenge_key(user)
    "staged-webauthn-challenge-#{user&.id}"
  end
end
