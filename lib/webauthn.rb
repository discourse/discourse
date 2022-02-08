# frozen_string_literal: true
require 'webauthn/challenge_generator'
require 'webauthn/security_key_base_validation_service'
require 'webauthn/security_key_registration_service'
require 'webauthn/security_key_authentication_service'

module Webauthn
  ACCEPTABLE_REGISTRATION_TYPE = "webauthn.create"
  ACCEPTABLE_AUTHENTICATION_TYPE = "webauthn.get"

  # -7   - ES256
  # -257 - RS256 (Windows Hello supported alg.)
  SUPPORTED_ALGORITHMS = COSE::Algorithm.registered_algorithm_ids.freeze
  VALID_ATTESTATION_FORMATS = ['none', 'packed', 'fido-u2f'].freeze

  class SecurityKeyError < StandardError; end

  class InvalidOriginError < SecurityKeyError; end
  class InvalidRelyingPartyIdError < SecurityKeyError; end
  class UserVerificationError < SecurityKeyError; end
  class ChallengeMismatchError < SecurityKeyError; end
  class InvalidTypeError < SecurityKeyError; end
  class UnsupportedPublicKeyAlgorithmError < SecurityKeyError; end
  class UnsupportedAttestationFormatError < SecurityKeyError; end
  class CredentialIdInUseError < SecurityKeyError; end
  class MalformedAttestationError < SecurityKeyError; end
  class NotFoundError < SecurityKeyError; end
  class OwnershipError < SecurityKeyError; end
  class PublicKeyError < SecurityKeyError; end
  class UnknownCOSEAlgorithmError < SecurityKeyError; end

  ##
  # Usage:
  #
  # These methods should be used in controllers where we
  # are challenging the user that has a security key, and
  # they must respond with a valid webauthn response and
  # credentials.
  def self.stage_challenge(user, secure_session)
    ::Webauthn::ChallengeGenerator.generate.commit_to_session(secure_session, user)
  end

  def self.allowed_credentials(user, secure_session)
    return {} if !user.security_keys_enabled?
    credential_ids = user.second_factor_security_key_credential_ids
    {
      allowed_credential_ids: credential_ids,
      challenge: secure_session[
        Webauthn::ChallengeGenerator::ChallengeSession.session_challenge_key(user)
      ]
    }
  end

  def self.rp_id(user, secure_session)
    secure_session[Webauthn::ChallengeGenerator::ChallengeSession.session_rp_id_key(user)]
  end

  def self.rp_name(user, secure_session)
    secure_session[Webauthn::ChallengeGenerator::ChallengeSession.session_rp_name_key(user)]
  end

  def self.challenge(user, secure_session)
    secure_session[Webauthn::ChallengeGenerator::ChallengeSession.session_challenge_key(user)]
  end
end
