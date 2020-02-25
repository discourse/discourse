# frozen_string_literal: true
require 'cose'

module Webauthn
  class SecurityKeyAuthenticationService < SecurityKeyBaseValidationService

    ##
    # See https://w3c.github.io/webauthn/#sctn-verifying-assertion for
    # the steps followed here. Memoized methods are called in their
    # place in the step flow to make the process clearer.
    def authenticate_security_key
      return false if @params.blank? || (!@params.is_a?(Hash) && !@params.is_a?(ActionController::Parameters))

      # 3. Identify the user being authenticated and verify that this user is the
      #    owner of the public key credential source credentialSource identified by credential.id:
      security_key = UserSecurityKey.find_by(credential_id: @params[:credentialId])
      raise(NotFoundError, I18n.t('webauthn.validation.not_found_error')) if security_key.blank?
      raise(OwnershipError, I18n.t('webauthn.validation.ownership_error')) if security_key.user != @current_user

      # 4. Using credential.id (or credential.rawId, if base64url encoding is inappropriate for your use case),
      #    look up the corresponding credential public key and let credentialPublicKey be that credential public key.
      public_key = security_key.public_key

      # 5. Let cData, authData and sig denote the value of credential’s response's clientDataJSON, authenticatorData, and signature respectively.
      # 6. Let JSONtext be the result of running UTF-8 decode on the value of cData.
      # 7. Let C, the client data claimed as used for the signature, be the result of running an implementation-specific JSON parser on JSONtext.
      client_data

      # 8. Verify that the value of C.type is the string webauthn.get.
      validate_webauthn_type(::Webauthn::ACCEPTABLE_AUTHENTICATION_TYPE)

      # 9. Verify that the value of C.challenge equals the base64url encoding of options.challenge.
      validate_challenge

      # 10. Verify that the value of C.origin matches the Relying Party's origin.
      validate_origin

      # 11. Verify that the value of C.tokenBinding.status matches the state of Token Binding for the TLS connection
      #     over which the attestation was obtained. If Token Binding was used on that TLS connection, also verify
      #     that C.tokenBinding.id matches the base64url encoding of the Token Binding ID for the connection.
      #     Not using this right now.

      # 12. Verify that the rpIdHash in authData is the SHA-256 hash of the RP ID expected by the Relying Party.
      validate_rp_id_hash

      # 13. Verify that the User Present bit of the flags in authData is set.
      # https://blog.bigbinary.com/2011/07/20/ruby-pack-unpack.html
      #
      # bit 0 is the least significant bit - LSB first
      #
      # 14. If user verification is required for this registration, verify that
      #     the User Verified bit of the flags in authData is set.
      validate_user_verification

      # 15. Verify that the values of the client extension outputs in clientExtensionResults and the authenticator
      #     extension outputs in the extensions in authData are as expected, considering the client extension input
      #     values that were given in options.extensions and any specific policy of the Relying Party regarding
      #     unsolicited extensions, i.e., those that were not specified as part of options.extensions. In the
      #     general case, the meaning of "are as expected" is specific to the Relying Party and which extensions are in use.
      #     Not using this right now.

      # 16. Let hash be the result of computing a hash over response.clientDataJSON using SHA-256.
      client_data_hash

      # 17. Using credentialPublicKey, verify that sig is a valid signature over the binary concatenation of authData and hash.
      cose_key = COSE::Key.deserialize(Base64.decode64(security_key.public_key))
      cose_algorithm = COSE::Algorithm.find(cose_key.alg)

      if cose_algorithm.blank?
        Rails.logger.error("Unknown COSE algorithm encountered. alg: #{cose_key.alg}. user_id: #{@current_user.id}. params: #{@params.inspect}")
        raise(UnknownCOSEAlgorithmError, I18n.t('webauthn.validation.unknown_cose_algorithm_error'))
      end

      if !cose_key.to_pkey.verify(cose_algorithm.hash_function, signature, auth_data + client_data_hash)
        raise(PublicKeyError, I18n.t('webauthn.validation.public_key_error'))
      end

      # Success! Update the last used at time for the key.
      security_key.update(last_used: Time.zone.now)
    rescue OpenSSL::PKey::PKeyError
      raise(PublicKeyError, I18n.t('webauthn.validation.public_key_error'))
    end

    private

    def auth_data
      @auth_data ||= Base64.decode64(@params[:authenticatorData])
    end

    def signature
      @signature ||= Base64.decode64(@params[:signature])
    end
  end
end
