# frozen_string_literal: true

module Webauthn
  class SecurityKeyAuthenticationService
    def initialize(current_user, params, challenge_params)
      @current_user = current_user
      @params = params
      @challenge_params = challenge_params
    end

    ##
    # See https://w3c.github.io/webauthn/#sctn-verifying-assertion for
    # the steps followed here.
    def authenticate_security_key
      return false if @params.blank?

      # 3. Identify the user being authenticated and verify that this user is the
      #    owner of the public key credential source credentialSource identified by credential.id:
      security_key = UserSecurityKey.find_by(credential_id: @params[:credentialId])
      raise(NotFoundError, I18n.t('webauthn.registration.not_found_error')) if security_key.blank?
      raise(OwnershipError, I18n.t('webauthn.registration.ownership_error')) if security_key.user != @current_user

      # 4. Using credential.id (or credential.rawId, if base64url encoding is inappropriate for your use case),
      #    look up the corresponding credential public key and let credentialPublicKey be that credential public key.
      public_key = security_key.public_key

      # 8. Verify that the value of C.type is the string webauthn.get.
      raise(InvalidTypeError, I18n.t('webauthn.registration.invalid_type_error')) if !webauthn_type_ok?

      # 9. Verify that the value of C.challenge equals the base64url encoding of options.challenge.
      raise(ChallengeMismatchError, I18n.t('webauthn.registration.challenge_mismatch_error')) if !challenge_match?

      # 10. Verify that the value of C.origin matches the Relying Party's origin.
      raise(InvalidOriginError, I18n.t('webauthn.registration.invalid_origin_error')) if !origin_match?

      # 11. Verify that the value of C.tokenBinding.status matches the state of Token Binding for the TLS connection
      #     over which the attestation was obtained. If Token Binding was used on that TLS connection, also verify
      #     that C.tokenBinding.id matches the base64url encoding of the Token Binding ID for the connection.
      #     Not using this right now.

      # 12. Verify that the rpIdHash in authData is the SHA-256 hash of the RP ID expected by the Relying Party.
      rp_id_hash = auth_data[0..31]
      raise(InvalidRelyingPartyIdError, I18n.t('webauthn.registration.invalid_relying_party_id_error')) if !rp_id_match?(rp_id_hash)

      # 13. Verify that the User Present bit of the flags in authData is set.
      # https://blog.bigbinary.com/2011/07/20/ruby-pack-unpack.html
      #
      # bit 0 is the least significant bit - LSB first
      #
      # 14. If user verification is required for this registration, verify that
      #     the User Verified bit of the flags in authData is set.
      flags = auth_data[32].unpack("b*")[0].split('')
      raise(UserVerificationError, I18n.t('webauthn.registration.user_verification_error')) if flags[0] != '1'

      # 14. Verify that the values of the client extension outputs in clientExtensionResults and the authenticator
      #     extension outputs in the extensions in authData are as expected, considering the client extension input
      #     values that were given in options.extensions and any specific policy of the Relying Party regarding
      #     unsolicited extensions, i.e., those that were not specified as part of options.extensions. In the
      #     general case, the meaning of "are as expected" is specific to the Relying Party and which extensions are in use.
      #     Not using this right now.

      # 16. Let hash be the result of computing a hash over the cData using SHA-256.
      hash = OpenSSL::Digest::SHA256.digest(client_data_json)

      # 17. Using credentialPublicKey, verify that sig is a valid signature over the binary concatenation of authData and hash.
      cose_key = COSE::Key.deserialize(Base64.decode64(security_key.public_key))
      if !cose_key.to_pkey.verify(COSE::Algorithm.find(cose_key.alg).hash_function, signature, auth_data + hash)
        raise(PublicKeyError, I18n.t('webauthn.registration.public_key_error'))
      end

      # Success! Update the last used at time for the key.
      security_key.update(last_used: Time.zone.now)
    end

    private

    # https://w3c.github.io/webauthn/#sctn-registering-a-new-credential
    # 5. Let JSONtext be the result of running UTF-8 decode on the value of response.clientDataJSON.
    def client_data_json
      @client_data_json ||= Base64.decode64(@params[:clientData])
    end

    # 6/7. Let C, the client data claimed as collected during the credential creation, be the result of running
    # an implementation-specific JSON parser on JSONtext.
    def client_data
      @client_data ||= JSON.parse(client_data_json)
    end

    def challenge_match?
      Base64.decode64(client_data['challenge']) == @challenge_params[:challenge]
    end

    def webauthn_type_ok?
      client_data['type'] == ::Webauthn::ACCEPTABLE_AUTHENTICATION_TYPE
    end

    def origin_match?
      client_data['origin'] == @challenge_params[:origin]
    end

    def rp_id_match?(rp_id_hash)
      rp_id_hash == OpenSSL::Digest::SHA256.digest(@challenge_params[:rp_id])
    end

    def auth_data
      @auth_data ||= Base64.decode64(@params[:authenticatorData])
    end

    def signature
      @signature ||= Base64.decode64(@params[:signature])
    end
  end
end
