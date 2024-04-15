# frozen_string_literal: true

module DiscourseWebauthn
  ACCEPTABLE_REGISTRATION_TYPE = "webauthn.create"
  ACCEPTABLE_AUTHENTICATION_TYPE = "webauthn.get"

  # -7   - ES256
  # -257 - RS256 (Windows Hello supported alg.)
  SUPPORTED_ALGORITHMS = COSE::Algorithm.registered_algorithm_ids.freeze
  VALID_ATTESTATION_FORMATS = %w[none packed fido-u2f].freeze

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
  def self.stage_challenge(user, secure_session)
    ::DiscourseWebauthn::ChallengeGenerator.generate.commit_to_session(secure_session, user)
  end

  def self.allowed_credentials(user, secure_session)
    return {} if !user.security_keys_enabled?
    credential_ids = user.second_factor_security_key_credential_ids
    {
      allowed_credential_ids: credential_ids,
      challenge: secure_session[self.session_challenge_key(user)],
    }
  end

  def self.challenge(user, secure_session)
    secure_session[self.session_challenge_key(user)]
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
