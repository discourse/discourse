# frozen_string_literal: true
require 'webauthn/security_key_registration_service'

module Webauthn
  ACCEPTABLE_REGISTRATION_TYPE = "webauthn.create".freeze
  SUPPORTED_ALGORITHMS = [-7].freeze
  VALID_ATTESTATION_FORMATS = ['none', 'packed', 'fido-u2f'].freeze
end
