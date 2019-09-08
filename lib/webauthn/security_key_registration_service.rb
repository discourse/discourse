# frozen_string_literal: true

module Webauthn
  class InvalidOriginError < StandardError; end
  class InvalidRelyingPartyIdError < StandardError; end
  class UserVerificationError < StandardError; end
  class ChallengeMismatchError < StandardError; end
  class InvalidTypeError < StandardError; end
  class UnsupportedPublicKeyAlgorithmError < StandardError; end
  class UnsupportedAttestationFormatError < StandardError; end
  class CredentialIdInUseError < StandardError; end
  class MalformedAttestationError < StandardError; end

  class SecurityKeyRegistrationService
    def initialize(current_user, params, challenge_params)
      @current_user = current_user
      @params = params
      @challenge_params = challenge_params
    end

    ##
    # See https://w3c.github.io/webauthn/#sctn-registering-a-new-credential for
    # the registration steps followed here.
    def register_second_factor_security_key
      # 4. Verify that the value of C.type is webauthn.create.
      raise(InvalidTypeError, I18n.t('webauthn.registration.invalid_type_error')) if !webauthn_type_ok?

      # 5. Verify that the value of C.challenge equals the base64url encoding of options.challenge.
      raise(ChallengeMismatchError, I18n.t('webauthn.registration.challenge_mismatch_error')) if !challenge_match?

      # 6. Verify that the value of C.origin matches the Relying Party's origin.
      raise(InvalidOriginError, I18n.t('webauthn.registration.invalid_origin_error')) if !origin_match?

      # 7. Verify that the value of C.tokenBinding.status matches the state of Token Binding for the TLS
      #    connection over which the assertion was obtained. If Token Binding was used on that TLS connection,
      #    also verify that C.tokenBinding.id matches the base64url encoding of the Token Binding ID for the connection.

      # 8. Let hash be the result of computing a hash over response.clientDataJSON using SHA-256.
      hash = OpenSSL::Digest::SHA256.digest(client_data_json)

      # 9. Perform CBOR decoding on the attestationObject field of the AuthenticatorAttestationResponse
      #    structure to obtain the attestation statement format fmt, the authenticator data authData,
      #    and the attestation statement attStmt.
      attestation = CBOR.decode(Base64.decode64(@params[:attestation]))

      # 10. Verify that the rpIdHash in authData is the SHA-256 hash of the RP ID expected by the Relying Party.
      # check the SHA256 hash of the rpId is the same as the authData bytes 0..31
      rp_id_hash = attestation['authData'][0..31]
      raise(InvalidRelyingPartyIdError, I18n.t('webauthn.registration.invalid_relying_party_id_error')) if !rp_id_match?(rp_id_hash)

      # 11. Verify that the User Present bit of the flags in authData is set.
      # https://blog.bigbinary.com/2011/07/20/ruby-pack-unpack.html
      #
      # bit 0 is the least significant bit - LSB first
      #
      # 12. If user verification is required for this registration, verify that
      #     the User Verified bit of the flags in authData is set.
      flags = attestation['authData'][32].unpack("b*")[0].split('')
      raise(UserVerificationError, I18n.t('webauthn.registration.user_verification_error')) if flags[0] != '1'

      # 13. Verify that the "alg" parameter in the credential public key in authData matches the alg attribute of one of the items in options.pubKeyCredParams.
      # https://w3c.github.io/webauthn/#table-attestedCredentialData
      # See https://www.iana.org/assignments/cose/cose.xhtml#algorithms for supported algorithm
      # codes, -7 which discourse uses is ECDSA w/ SHA-256
      credential_public_key, credential_public_key_bytes, credential_id = extract_public_key_and_credential_from_attestation(attestation['authData'])
      raise(UnsupportedPublicKeyAlgorithmError, I18n.t('webauthn.registration.unsupported_public_key_algorithm_error')) if ::Webauthn::SUPPORTED_ALGORITHMS.exclude?(credential_public_key.alg)

      # 14. Verify that the values of the client extension outputs in clientExtensionResults and the authenticator
      #     extension outputs in the extensions in authData are as expected, considering the client extension input
      #     values that were given in options.extensions. In particular, any extension identifier values in the
      #     clientExtensionResults and the extensions in authData MUST also be present as extension identifier values
      #     in options.extensions, i.e., no extensions are present that were not requested. In the general case, the
      #     meaning of "are as expected" is specific to the Relying Party and which extensions are in use.

      # 15. Determine the attestation statement format by performing a USASCII case-sensitive match on fmt against the
      #     set of supported WebAuthn Attestation Statement Format Identifier values. An up-to-date list of registered
      #     WebAuthn Attestation Statement Format Identifier values is maintained in the IANA registry of the same
      #     name [WebAuthn-Registries].
      # 16. Verify that attStmt is a correct attestation statement, conveying a valid attestation signature,
      #     by using the attestation statement format fmt’s verification procedure given attStmt, authData and hash.
      if ::Webauthn::VALID_ATTESTATION_FORMATS.exclude?(attestation['fmt']) || attestation['fmt'] != 'none'
        raise(UnsupportedAttestationFormatError, I18n.t('webauthn.registration.unsupported_attestation_format_error'))
      end

      #==================================================
      # ONLY APPLIES IF fmt !== none, this is all to do with
      # verifying attestation. May want to come back to this at
      # some point for additional security.
      #==================================================
      #
      # 17. If validation is successful, obtain a list of acceptable trust anchors (attestation root certificates or
      #     ECDAA-Issuer public keys) for that attestation type and attestation statement format fmt, from a trusted
      #     source or from policy. For example, the FIDO Metadata Service [FIDOMetadataService] provides one way
      #     to obtain such information, using the aaguid in the attestedCredentialData in authData.
      # ignore for none
      #
      # 18. Assess the attestation trustworthiness using the outputs of the verification procedure in step 16, as follows:
      #     If no attestation was provided, verify that None attestation is acceptable under Relying Party policy.\
      # ignore for none
      #==================================================

      # 19. Check that the credentialId is not yet registered to any other user. If registration is requested for a
      #     credential that is already registered to a different user, the Relying Party SHOULD fail this registration ceremony,
      #     or it MAY decide to accept the registration, e.g. while deleting the older registration.
      encoded_credential_id = Base64.encode64(credential_id)
      endcoded_public_key = Base64.encode64(credential_public_key_bytes)
      raise(CredentialIdInUseError, I18n.t('webauthn.registration.credential_id_in_use_error')) if UserSecurityKey.exists?(credential_id: encoded_credential_id)

      # 20. If the attestation statement attStmt verified successfully and is found to be trustworthy, then register
      #     the new credential with the account that was denoted in options.user, by associating it with the credentialId
      #     and credentialPublicKey in the attestedCredentialData in authData, as appropriate for the Relying Party's system.
      UserSecurityKey.create(
        user: @current_user,
        credential_id: encoded_credential_id,
        public_key: endcoded_public_key,
        name: @params[:name],
        factor_type: UserSecurityKey.factor_types[:second_factor]
      )
    rescue CBOR::UnpackError, CBOR::TypeError, CBOR::MalformedFormatError, CBOR::StackError
      raise MalformedAttestationError, I18n.t('webauthn.registration.malformed_attestation_error')
    end

    private

    # https://w3c.github.io/webauthn/#sctn-registering-a-new-credential
    # 2. Let JSONtext be the result of running UTF-8 decode on the value of response.clientDataJSON.
    def client_data_json
      @client_data_json ||= Base64.decode64(@params[:clientData])
    end

    # 3. Let C, the client data claimed as collected during the credential creation, be the result of running an implementation-specific JSON parser on JSONtext.
    def client_data
      @client_data ||= JSON.parse(client_data_json)
    end

    def webauthn_type_ok?
      client_data['type'] == ::Webauthn::ACCEPTABLE_REGISTRATION_TYPE
    end

    def challenge_match?
      Base64.decode64(client_data['challenge']) == @challenge_params[:challenge]
    end

    def origin_match?
      client_data['origin'] == @challenge_params[:origin]
    end

    def rp_id_match?(rp_id_hash)
      rp_id_hash == OpenSSL::Digest::SHA256.digest(@challenge_params[:rp_id])
    end

    def extract_public_key_and_credential_from_attestation(auth_data)
      # see https://w3c.github.io/webauthn/#authenticator-data for lengths
      # of authdata for extraction
      rp_id_length = 32
      flags_length = 1
      sign_count_length = 4

      attested_credential_data_start_position = rp_id_length + flags_length + sign_count_length # 37
      attested_credential_data_length = auth_data.size - attested_credential_data_start_position
      attested_credential_data = auth_data[
        attested_credential_data_start_position..(attested_credential_data_start_position + attested_credential_data_length - 1)
      ]

      # see https://w3c.github.io/webauthn/#attested-credential-data for lengths
      # of data for extraction
      aa_guid = attested_credential_data[0..15]
      credential_id_length = attested_credential_data[16..18].unpack("n*")[0]
      credential_id = attested_credential_data[18..(18 + credential_id_length)]

      public_key_start_position = 18 + credential_id_length
      public_key_bytes = attested_credential_data[public_key_start_position..(public_key_start_position + attested_credential_data.size - 1)]
      public_key = COSE::Key.deserialize(public_key_bytes)

      [public_key, public_key_bytes, credential_id]
    end
  end
end
