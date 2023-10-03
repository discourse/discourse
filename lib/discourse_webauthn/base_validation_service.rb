# frozen_string_literal: true

module DiscourseWebauthn
  class BaseValidationService
    def initialize(current_user, params, session:, factor_type:)
      @current_user = current_user
      @params = params
      @factor_type = factor_type
      @session = session
    end

    def validate_webauthn_type(type_to_check)
      return if client_data["type"] == type_to_check
      raise(InvalidTypeError, I18n.t("webauthn.validation.invalid_type_error"))
    end

    def validate_challenge
      return if challenge_match?
      raise(ChallengeMismatchError, I18n.t("webauthn.validation.challenge_mismatch_error"))
    end

    def validate_origin
      return if origin_match?
      raise(InvalidOriginError, I18n.t("webauthn.validation.invalid_origin_error"))
    end

    def validate_rp_id_hash
      return if rp_id_hash_match?
      raise(
        InvalidRelyingPartyIdError,
        I18n.t("webauthn.validation.invalid_relying_party_id_error"),
      )
    end

    ## flags per specification
    # https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data
    # bit 0 - user presence
    # bit 1 - reserved for future use
    # bit 2 - user verification
    # bit 3-5 - reserved for future use
    # bit 6 - attested credential data
    # bit 7 - extension data

    def validate_user_presence
      flags = auth_data[32].unpack("b*")[0].split("")
      # bit 0 - user presence
      return if flags[0] == "1"
      raise(UserPresenceError, I18n.t("webauthn.validation.user_presence_error"))
    end

    def validate_user_verification
      flags = auth_data[32].unpack("b*")[0].split("")
      # bit 2 - user verification
      return if flags[2] == "1"
      raise(UserVerificationError, I18n.t("webauthn.validation.user_verification_error"))
    end

    private

    # https://w3c.github.io/webauthn/#sctn-registering-a-new-credential
    # Let JSONtext be the result of running UTF-8 decode on the value of response.clientDataJSON.
    def client_data_json
      @client_data_json ||= Base64.decode64(@params[:clientData])
    end

    # Let C, the client data claimed as collected during the credential creation, be the result of running
    # an implementation-specific JSON parser on JSONtext.
    def client_data
      @client_data ||= JSON.parse(client_data_json)
    end

    def challenge_match?
      Base64.decode64(client_data["challenge"]) ==
        DiscourseWebauthn.challenge(@current_user, @session)
    end

    def origin_match?
      client_data["origin"] == DiscourseWebauthn.origin
    end

    def rp_id_hash_match?
      auth_data[0..31] == OpenSSL::Digest::SHA256.digest(DiscourseWebauthn.rp_id)
    end

    def client_data_hash
      @client_data_hash ||= OpenSSL::Digest::SHA256.digest(client_data_json)
    end
  end
end
