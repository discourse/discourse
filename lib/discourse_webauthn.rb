# frozen_string_literal: true
require "webauthn/challenge_generator"
require "webauthn/security_key_base_validation_service"
require "webauthn/security_key_registration_service"
require "webauthn/security_key_authentication_service"

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
  class NotFoundError < SecurityKeyError
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
      challenge:
        secure_session[
          DiscourseWebauthn::ChallengeGenerator::ChallengeSession.session_challenge_key(user)
        ],
    }
  end

  def self.rp_id(user, secure_session)
    secure_session[DiscourseWebauthn::ChallengeGenerator::ChallengeSession.session_rp_id_key(user)]
  end

  def self.rp_name(user, secure_session)
    secure_session[
      DiscourseWebauthn::ChallengeGenerator::ChallengeSession.session_rp_name_key(user)
    ]
  end

  def self.challenge(user, secure_session)
    secure_session[
      DiscourseWebauthn::ChallengeGenerator::ChallengeSession.session_challenge_key(user)
    ]
  end

  def self.validate_first_factor_key(key)
    pp key
    webauthn_credential = DiscourseWebauthn::Credential.from_get(key)
    p "webauthn_credential"
    pp webauthn_credential

    # stored_credential = user.credentials.find_by(webauthn_id: webauthn_credential.id)

    # begin
    #   webauthn_credential.verify(
    #     session[:authentication_challenge],
    #     public_key: stored_credential.public_key,
    #     sign_count: stored_credential.sign_count
    #   )

    #   # Update the stored credential sign count with the value from `webauthn_credential.sign_count`
    #   stored_credential.update!(sign_count: webauthn_credential.sign_count)

    #   # Continue with successful sign in or 2FA verification...

    # rescue ::WebAuthn::SignCountVerificationError => e
    #   # Cryptographic verification of the authenticator data succeeded, but the signature counter was less then or equal
    #   # to the stored value. This can have several reasons and depending on your risk tolerance you can choose to fail or
    #   # pass authentication. For more information see https://www.w3.org/TR/webauthn/#sign-counter
    #   pp e
    # rescue ::WebAuthn::Error => e
    #   # Handle error
    # end
  end
end
