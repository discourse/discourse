# frozen_string_literal: true
require "cose"

module DiscourseWebauthn
  class AuthenticationService < BaseValidationService
    ##
    # See https://w3c.github.io/webauthn/#sctn-verifying-assertion for
    # the steps followed here. Memoized methods are called in their
    # place in the step flow to make the process clearer.
    def authenticate_security_key
      # Steps 1-5 of this authentication flow are in the frontend at lib/webauthn.js
      if @params.blank? || (!@params.is_a?(Hash) && !@params.is_a?(ActionController::Parameters))
        raise(
          MalformedPublicKeyCredentialError,
          I18n.t("webauthn.validation.malformed_public_key_credential_error"),
        )
      end

      # 6. Identify the user being authenticated and verify that this user is the
      #    owner of the public key credential source credentialSource identified by credential.id:

      # 6a. If the user was identified before the authentication ceremony was initiated,
      #     verify that the identified user account contains a credential record whose id equals credential.rawId.
      security_key = UserSecurityKey.find_by(credential_id: @params[:credentialId])
      raise(KeyNotFoundError, I18n.t("webauthn.validation.not_found_error")) if security_key.blank?

      if @factor_type == UserSecurityKey.factor_types[:second_factor] &&
           (@current_user == nil || security_key.user == nil || security_key.user != @current_user)
        raise(OwnershipError, I18n.t("webauthn.validation.ownership_error"))
      end

      # 6b. If the user was not identified before the authentication ceremony was initiated,
      #     verify that response.userHandle is present. Verify that the user account identified by response.userHandle
      #     contains a credential record whose id equals credential.rawId
      if @factor_type == UserSecurityKey.factor_types[:first_factor] &&
           Base64.decode64(@params[:userHandle]) != security_key.user.secure_identifier
        raise(OwnershipError, I18n.t("webauthn.validation.ownership_error"))
      end

      # 7. No upstream step
      # 8. No upstream step

      # 9. Let cData, authData and sig denote the value of credential’s response's clientDataJSON, authenticatorData, and signature respectively.
      # 10. Let JSONtext be the result of running UTF-8 decode on the value of cData.
      # 11. Let C, the client data claimed as used for the signature, be the result of running an implementation-specific JSON parser on JSONtext.
      client_data

      # 12. Verify that the value of C.type is the string webauthn.get.
      validate_webauthn_type(::DiscourseWebauthn::ACCEPTABLE_AUTHENTICATION_TYPE)

      # 13. Verify that the value of C.challenge equals the base64url encoding of options.challenge.
      validate_challenge

      # 14. Verify that the value of C.origin matches the Relying Party's origin.
      validate_origin

      # 15. If C.topOrigin is present:
      # - Verify that the Relying Party expects this credential to be used within an iframe that is not same-origin with its ancestors.
      # - Verify that the value of C.topOrigin matches the origin of a page that the Relying Party expects to be sub-framed within.
      # We are not using this.

      # 16. Verify that the rpIdHash in authData is the SHA-256 hash of the RP ID expected by the Relying Party.
      validate_rp_id_hash

      # 17. Verify that the User Present bit of the flags in authData is set.
      # https://blog.bigbinary.com/2011/07/20/ruby-pack-unpack.html
      #
      validate_user_presence

      #
      # 18. Determine whether user verification is required for this assertion.
      #     User verification SHOULD be required if, and only if, options.userVerification is set to required.
      #     If user verification was determined to be required, verify that the UV bit of the flags in authData is set.
      #     Otherwise, ignore the value of the UV flag.
      validate_user_verification if @factor_type == UserSecurityKey.factor_types[:first_factor]

      # 19. If the BE bit of the flags in authData is not set, verify that the BS bit is not set.
      #     Not using this right now.
      # 20. If the credential backup state is used as part of Relying Party business logic or policy...
      #     Not using this right now.
      # 21. Verify that the values of the client extension outputs in clientExtensionResults...
      #     Not using this right now.

      # 22. Let hash be the result of computing a hash over response.clientDataJSON using SHA-256.
      client_data_hash

      # 23. Using credentialPublicKey, verify that sig is a valid signature over the binary concatenation of authData and hash.
      cose_key = COSE::Key.deserialize(Base64.decode64(security_key.public_key))
      cose_algorithm = COSE::Algorithm.find(cose_key.alg)

      if cose_algorithm.blank?
        Rails.logger.error(
          "Unknown COSE algorithm encountered. alg: #{cose_key.alg}. user_id: #{@current_user.id}. params: #{@params.inspect}",
        )
        raise(UnknownCOSEAlgorithmError, I18n.t("webauthn.validation.unknown_cose_algorithm_error"))
      end

      if !cose_key.to_pkey.verify(
           cose_algorithm.hash_function,
           signature,
           auth_data + client_data_hash,
         )
        raise(PublicKeyError, I18n.t("webauthn.validation.public_key_error"))
      end

      # 24. If authData.signCount is nonzero or credentialRecord.signCount is nonzero...
      #     Not using this right now.

      # 25. If response.attestationObject is present and the Relying Party wishes to verify the attestation...
      #     Not using this right now.

      # 26. Success! Update the last used at time for the key (credentialRecord).
      security_key.update(last_used: Time.zone.now)

      # Return security key record so controller can use it to update the session
      security_key
    rescue OpenSSL::PKey::PKeyError
      raise(PublicKeyError, I18n.t("webauthn.validation.public_key_error"))
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
