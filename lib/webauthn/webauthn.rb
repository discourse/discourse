# frozen_string_literal: true
require 'webauthn/security_key_base_validation_service'
require 'webauthn/security_key_registration_service'
require 'webauthn/security_key_authentication_service'

module Webauthn
  ACCEPTABLE_REGISTRATION_TYPE = "webauthn.create".freeze
  ACCEPTABLE_AUTHENTICATION_TYPE = "webauthn.get".freeze
  SUPPORTED_ALGORITHMS = [-7].freeze
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
end
