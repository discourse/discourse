# frozen_string_literal: true
require "discourse_webauthn"

RSpec.describe DiscourseWebauthn::RegistrationService do
  subject(:service) { described_class.new(current_user, params, **options) }

  let(:secure_session) { SecureSession.new("tester") }
  let(:client_data_challenge) { Base64.encode64(challenge) }
  let(:client_data_webauthn_type) { "webauthn.create" }
  let(:client_data_origin) { "http://test.localhost" }
  let(:client_data_param) do
    {
      challenge: client_data_challenge,
      type: client_data_webauthn_type,
      origin: client_data_origin,
    }
  end
  ##
  # This attestation object was sourced by manually registering
  # a key with `navigator.credentials.create` and capturing the
  # results in localhost. It does not have a user verification
  # flag set (i.e. it is only usable as 2FA).
  let(:attestation) do
    "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVjESZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2NBAAAAAAAAAAAAAAAAAAAAAAAAAAAAQFmvayWc8OPJ4jj4sevfxBmvUglDMZrFalyokYrdnqOVvudC0lQialaGQv72eBzJM2Qn1GfJI7lpBgFJMprisLSlAQIDJiABIVgg+23/BZux7LK0/KQgCiQGtdr51ar+vfTtHWpRtN17gOwiWCBstV918mugVBexg/rdZjTs0wN/upHFoyBiAJCaGVD8OA=="
  end
  let(:params) do
    {
      clientData: Base64.encode64(client_data_param.to_json),
      attestation: attestation,
      name: "My Yubikey",
    }
  end
  ##
  # The above attestation was generated in localhost; Discourse.current_hostname
  # returns test.localhost which we do not want
  let(:options) do
    { session: secure_session, factor_type: UserSecurityKey.factor_types[:second_factor] }
  end

  let(:challenge) { DiscourseWebauthn.stage_challenge(current_user, secure_session).challenge }

  let(:current_user) { Fabricate(:user) }

  context "when the client data webauthn type is not webauthn.create" do
    let(:client_data_webauthn_type) { "webauthn.explode" }

    it "raises an InvalidTypeError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::InvalidTypeError,
        I18n.t("webauthn.validation.invalid_type_error"),
      )
    end
  end

  context "when the decoded challenge does not match the original challenge provided by the server" do
    let(:client_data_challenge) { Base64.encode64("invalid challenge") }

    it "raises a ChallengeMismatchError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::ChallengeMismatchError,
        I18n.t("webauthn.validation.challenge_mismatch_error"),
      )
    end
  end

  context "when the origin of the client data does not match the server origin" do
    let(:client_data_origin) { "https://someothersite.com" }

    it "raises a InvalidOriginError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::InvalidOriginError,
        I18n.t("webauthn.validation.invalid_origin_error"),
      )
    end
  end

  context "when the sha256 hash of the relaying party ID does not match the one in attestation.authData" do
    it "raises a InvalidRelyingPartyIdError" do
      DiscourseWebauthn.stubs(:rp_id).returns("bad_rp_id")

      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::InvalidRelyingPartyIdError,
        I18n.t("webauthn.validation.invalid_relying_party_id_error"),
      )
    end
  end

  context "when the public key algorithm is not supported by the server" do
    before do
      @original_supported_alg_value = DiscourseWebauthn::SUPPORTED_ALGORITHMS
      silence_warnings { DiscourseWebauthn::SUPPORTED_ALGORITHMS = [-999].freeze }
    end

    it "raises a UnsupportedPublicKeyAlgorithmError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::UnsupportedPublicKeyAlgorithmError,
        I18n.t("webauthn.validation.unsupported_public_key_algorithm_error"),
      )
    end

    after do
      silence_warnings { DiscourseWebauthn::SUPPORTED_ALGORITHMS = @original_supported_alg_value }
    end
  end

  context "when the attestation format is not supported" do
    before do
      @original_supported_alg_value = DiscourseWebauthn::VALID_ATTESTATION_FORMATS
      silence_warnings { DiscourseWebauthn::VALID_ATTESTATION_FORMATS = ["err"].freeze }
    end

    it "raises a UnsupportedAttestationFormatError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::UnsupportedAttestationFormatError,
        I18n.t("webauthn.validation.unsupported_attestation_format_error"),
      )
    end

    after do
      silence_warnings do
        DiscourseWebauthn::VALID_ATTESTATION_FORMATS = @original_supported_alg_value
      end
    end
  end

  context "when the credential id is already in use for any user" do
    it "raises a CredentialIdInUseError" do
      # register the key to the current user
      security_key = service.register_security_key

      # update the key to be on a different user
      other_user = Fabricate(:user)
      security_key.update(user: other_user)

      # error!
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::CredentialIdInUseError,
        I18n.t("webauthn.validation.credential_id_in_use_error"),
      )
    end
  end

  context "when the attestation data is malformed" do
    let(:attestation) do
      "blah/krrmihjLHmVzzuoMdl2NBAAAAAAAAAAAAAAAAAAAAAAAAAAAAQFmvayWc8OPJ4jj4sevfxBmvUglDMZrFalyokYrdnqOVvudC0lQialaGQv72eBzJM2Qn1GfJI7lpBgFJMprisLSlAQIDJiABIVgg+23/BZux7LK0/KQgCiQGtdr51ar+vfTtHWpRtN17gOwiWCBstV918mugVBexg/rdZjTs0wN/upHFoyBiAJCaGVD8OA=="
    end

    it "raises a MalformedAttestationError" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::MalformedAttestationError,
        I18n.t("webauthn.validation.malformed_attestation_error"),
      )
    end
  end

  context "when the user presence flag is false" do
    it "raises a UserPresenceError" do
      # simulate missing user presence by flipping first bit to 0
      flags = "00000010"
      overriddenAuthData = service.send(:auth_data)
      overriddenAuthData[32] = [flags].pack("b*")

      service.instance_variable_set(:@auth_data, overriddenAuthData)

      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::UserPresenceError,
        I18n.t("webauthn.validation.user_presence_error"),
      )
    end
  end

  it "registers a valid second-factor key" do
    key = service.register_security_key
    expect(key).to be_a(UserSecurityKey)
    expect(key.user).to eq(current_user)
    expect(key.factor_type).to eq(UserSecurityKey.factor_types[:second_factor])
  end

  describe "registering a second factor key as first factor" do
    let(:options) do
      { factor_type: UserSecurityKey.factor_types[:first_factor], session: secure_session }
    end

    it "does not work since second-factor key does not have the user verification flag" do
      expect { service.register_security_key }.to raise_error(
        DiscourseWebauthn::UserVerificationError,
        I18n.t("webauthn.validation.user_verification_error"),
      )
    end
  end

  describe "registering a passkey" do
    let(:options) do
      { factor_type: UserSecurityKey.factor_types[:first_factor], session: secure_session }
    end

    ##
    # key registered locally using
    # - localhost:3000 as the origin (via an origin override in discourse_webauthn.rb)
    # - frontend webauthn.create has user verification flag enabled
    let(:attestation) do
      "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVikSZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2NFAAAAAK3OAAI1vMYKZIsLJfHwVQMAICRXq4sFZ9XpWZOzfJ8EguJmoEPMzNVyFMUWQfT5u1QzpQECAyYgASFYILjOiAHAwNrXkCk/tmyYRiE87QyV/15wUvhcXhr1JfwtIlggClQywgQvSxTsqV/FSK0cNHTTmuwfzzREqE6eLDmPxmI="
    end

    it "works with a valid key" do
      key = service.register_security_key
      expect(key).to be_a(UserSecurityKey)
      expect(key.user).to eq(current_user)
      expect(key.factor_type).to eq(UserSecurityKey.factor_types[:first_factor])
    end

    context "when the user verification flag in the key is false" do
      it "raises a UserVerificationError" do
        # simulate missing user verification by flipping third bit to 0
        flags = "10000010" # correct flag sequence is "10100010"
        overridden_auth_data = service.send(:auth_data)
        overridden_auth_data[32] = [flags].pack("b*")

        service.instance_variable_set(:@auth_data, overridden_auth_data)

        expect { service.register_security_key }.to raise_error(
          DiscourseWebauthn::UserVerificationError,
          I18n.t("webauthn.validation.user_verification_error"),
        )
      end
    end
  end
end
