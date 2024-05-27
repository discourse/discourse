# frozen_string_literal: true
require "discourse_webauthn"

##
# These tests use the following parameters generated on a local discourse
# instance to test an actual authentication flow:
#
# - credential_id
# - public_key
# - challenge
# - signature
# - authenticator_data
# - client_data_origin
#
# To create another test (e.g. for a different COSE algorithm) you need to:
#
# 1. Add a security key for a user on a local discourse instance. Go into
# the console and get the credential_id and public_key params from there.
# 2. Log out and try to log back in to that user to get the security
# key challenge
# 3. Touch the security key. Inside the authenticate_security_key method
# you need to add puts debugger statements (or use binding.pry) like so:
#
# puts client_data
# puts @params
#
# The client_data will have the challenge param, but you must Base64.decode64 to
# use it in the let(:challenge) variable.
#
# puts Base64.decode64(client_data["challenge"])
#
# You also need to make sure that client_data_param has the exact same structure
# and order of keys, otherwise even with everything else right the
# public key verification will fail.
#
# @params will contain authenticatorData and signature which you can use as is.
#
# The origin param needs to be http://localhost:3000 (that's the port tests run on)

RSpec.describe DiscourseWebauthn::AuthenticationService do
  subject(:service) { described_class.new(current_user, params, **options) }

  let(:security_key_user) { current_user }
  let!(:security_key) do
    Fabricate(
      :user_security_key,
      credential_id: credential_id,
      public_key: public_key,
      user: security_key_user,
      factor_type: UserSecurityKey.factor_types[:second_factor],
      last_used: nil,
      name: "Some key",
    )
  end
  let(:public_key) do
    "pQECAyYgASFYIMNgw4GCpwBUlR2SznJ1yY7B9yFvsuxhfo+C9kcA4IitIlggRdofrCezymy2B/YarX+gfB6gZKg648/cHIMjf6wWmmU="
  end
  let(:credential_id) do
    "mJAJ4CznTO0SuLkJbYwpgK75ao4KMNIPlU5KWM92nq39kRbXzI9mSv6GxTcsMYoiPgaouNw7b7zBiS4vsQaO6A=="
  end
  let(:secure_session) { SecureSession.new("tester") }
  let(:challenge) { "81d4acfbd69eafa8f02bc2ecbec5267be8c9b28c1e0ba306d52b79f0f13d" }
  let(:client_data_challenge) { Base64.strict_encode64(challenge) }
  let(:client_data_webauthn_type) { "webauthn.get" }
  let(:client_data_origin) { "http://localhost:3000" }

  ##
  # IMPORTANT: For the SHA256 hash to match the same one as was used to generate
  # the values for this spec, the three keys and values must be in the same order
  # (challenge, origin, type)
  let(:client_data_param) do
    {
      challenge: client_data_challenge,
      origin: client_data_origin,
      type: client_data_webauthn_type,
    }
  end
  ##
  # These are sourced from an actual login using the UserSecurityKey credential
  # defined in this spec, generated via a local discourse.
  let(:signature) do
    "MEUCIBppPyK8blxBDoktU54mI1vWEY96r1V5H1rEBtPDxwcGAiEAoi7LCmMoEAuWYu0krZpflZlULsbURCGcqOwP06amXYE="
  end
  let(:authenticator_data) { "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAAVw==" }
  let(:params) do
    {
      clientData: Base64.strict_encode64(client_data_param.to_json),
      credentialId: credential_id,
      authenticatorData: authenticator_data,
      signature: signature,
    }
  end

  let(:options) do
    { session: secure_session, factor_type: UserSecurityKey.factor_types[:second_factor] }
  end
  let(:current_user) { Fabricate(:user) }

  before do
    # we have to stub here because the test public key was created
    # using this specific challenge and this origin
    DiscourseWebauthn.stubs(:challenge).returns(challenge)
    DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
  end

  it "updates last_used when the security key and params are valid" do
    expect(service.authenticate_security_key).to eq(security_key)
    expect(security_key.reload.last_used).not_to eq(nil)
  end

  context "when params is blank" do
    let(:params) { nil }
    it "raises a MalformedPublicKeyCredentialError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::MalformedPublicKeyCredentialError,
        I18n.t("webauthn.validation.malformed_public_key_credential_error"),
      )
    end
  end

  context "when params is not blank and not a hash" do
    let(:params) { "test" }
    it "raises a MalformedPublicKeyCredentialError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::MalformedPublicKeyCredentialError,
        I18n.t("webauthn.validation.malformed_public_key_credential_error"),
      )
    end
  end

  context "when the credential ID does not match any user security key in the database" do
    before { security_key.destroy }

    it "raises a NotFoundError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::KeyNotFoundError,
        I18n.t("webauthn.validation.not_found_error"),
      )
    end
  end

  context "when the credential ID does exist but it is for a different user" do
    let(:security_key_user) { Fabricate(:user) }

    it "raises an OwnershipError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::OwnershipError,
        I18n.t("webauthn.validation.ownership_error"),
      )
    end
  end

  context "when the second-factor authentication is initiated without a user" do
    let(:current_user) { nil }
    let(:security_key_user) { Fabricate(:user) }

    it "raises an OwnershipError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::OwnershipError,
        I18n.t("webauthn.validation.ownership_error"),
      )
    end
  end

  context "when the client data webauthn type is not webauthn.get" do
    let(:client_data_webauthn_type) { "webauthn.explode" }

    it "raises an InvalidTypeError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::InvalidTypeError,
        I18n.t("webauthn.validation.invalid_type_error"),
      )
    end
  end

  context "when the decoded challenge does not match the original challenge provided by the server" do
    let(:client_data_challenge) { Base64.strict_encode64("invalid challenge") }

    it "raises a ChallengeMismatchError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::ChallengeMismatchError,
        I18n.t("webauthn.validation.challenge_mismatch_error"),
      )
    end
  end

  context "when the origin of the client data does not match the server origin" do
    let(:client_data_origin) { "https://someothersite.com" }

    it "raises a InvalidOriginError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::InvalidOriginError,
        I18n.t("webauthn.validation.invalid_origin_error"),
      )
    end
  end

  context "when the sha256 hash of the relaying party ID does not match the one in attestation.authData" do
    it "raises a InvalidRelyingPartyIdError" do
      DiscourseWebauthn.stubs(:rp_id).returns("bad_rp_id")

      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::InvalidRelyingPartyIdError,
        I18n.t("webauthn.validation.invalid_relying_party_id_error"),
      )
    end
  end

  context "when there is a problem verifying the public key (e.g. invalid signature)" do
    let(:signature) { Base64.strict_encode64("badsig") }

    it "raises a PublicKeyError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::PublicKeyError,
        I18n.t("webauthn.validation.public_key_error"),
      )
    end
  end

  context "when the COSE algorithm used cannot be found" do
    before { COSE::Algorithm.expects(:find).returns(nil) }

    it "raises a UnknownCOSEAlgorithmError" do
      expect { service.authenticate_security_key }.to raise_error(
        DiscourseWebauthn::UnknownCOSEAlgorithmError,
        I18n.t("webauthn.validation.unknown_cose_algorithm_error"),
      )
    end
  end

  context "for windows hello (alg -257)" do
    ##
    # These are sourced from an actual login using the UserSecurityKey credential
    # defined in this spec, generated via a local discourse.
    let(:challenge) { "fa7cb122f8713745dc08e16863e087ffa2d3bfda7f1b0386ea4b14635bb6" }
    let(:signature) do
      "OKEP/8oiojjE+LBwg6F37yJzjOTT9mBPukrW1E8Sih5Vh/3p9WHrqZdylxr1x9z/c8GplC0ABayanpAqN/miQezt3wm97gIwoHq/6rrmHDZu6irQhpjeX9yHRlu0lQw+SUEZfoW3iB4oP/d2ryYlafFA9intm++lLlP/qI3mvpCQwkAeotaelx7fn0RwiY767dG+bGVPyYuUicGHcLLvCY2k0G8kRQ7I5SQqB+dIcOINWikC9I2xvUKu6Br7hZZIrDy+soFtdnnCnvi2q/3ocOPYL5jy58wdpCTsh1RRPIEF/fQFVDOXtdS7PVgaa0PMBcWMCe5TimwGlTlICnsm+g=="
    end
    let(:authenticator_data) { "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MFAAAABA==" }
    let(:credential_id) { "8AddFow3jT87k1UPWvjn+rOetCEambpESGZ+z/63hOE=" }
    let(:public_key) do
      "pAEDAzkBACBZAQCqsl50KrR5zVm/QT9vWkeGTGxby32m0QRtCRh2UWseqoG0ZmBhGeWEYvkdoYlB1jObQKEHsAeB+1NBf5q69/88AA5zv4fzrvCydCtL41EUsHYFEbaPGnB61zZmYVLTPI7BYa+fu4F4MzFa924s36tVlU/L7n04peviJVZW2C1YIQfwOGDZJSvUpqJoZMQtw1vGRfrb4cQKlHfrpDZUpa3QLE8phh4ce4nwtX1tUnUGgCy8sOaFVkDNufENGTNr8HdAIHcinUiax3yy/Q8LjSZb8UR2ha6oXSe1vRHhj001B/P/mr5AdVMxSrOT1sUNXWkHv8L8IzS/iTBQpsC8CADZIUMBAAE="
    end
    # This key was generated using this specific origin
    let(:client_data_origin) { "http://localhost:4200" }

    # This has to be in the exact same order with the same data as it was originally
    # generated.
    let(:client_data_param) do
      {
        type: client_data_webauthn_type,
        challenge: client_data_challenge,
        origin: client_data_origin,
        crossOrigin: false,
        other_keys_can_be_added_here:
          "do not compare clientDataJSON against a template. See https://goo.gl/yabPex",
      }
    end

    it "updates last_used when the security key and params are valid" do
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:4200")

      expect(service.authenticate_security_key).to eq(security_key)
      expect(security_key.reload.last_used).not_to eq(nil)
    end
  end

  it "all supported algorithms are implemented" do
    DiscourseWebauthn::SUPPORTED_ALGORITHMS.each do |alg|
      expect(COSE::Algorithm.find(alg)).not_to be_nil
    end
  end

  describe "authenticating passkeys" do
    let(:options) do
      { factor_type: UserSecurityKey.factor_types[:first_factor], session: secure_session }
    end

    ##
    # These are sourced from an actual key, see instructions at the top of this spec for details
    #
    let(:public_key) { valid_passkey_data[:public_key] }
    let(:credential_id) { valid_passkey_data[:credential_id] }
    let(:signature) { valid_passkey_auth_data[:signature] }
    let(:authenticator_data) { valid_passkey_auth_data[:authenticatorData] }
    let(:challenge) { valid_passkey_challenge }

    let(:client_data_param) { passkey_client_data_param("webauthn.get") }

    let!(:security_key) do
      Fabricate(
        :user_security_key,
        credential_id: credential_id,
        public_key: public_key,
        user: security_key_user,
        factor_type: UserSecurityKey.factor_types[:first_factor],
        last_used: nil,
        name: "A key",
      )
    end

    before do
      # this essentially bypasses the user handle check for this key
      # a real test would need to go through the full registration/authentication flow in one go
      params[:userHandle] = Base64.strict_encode64(
        security_key_user.create_or_fetch_secure_identifier,
      )
    end

    context "with a valid passkey" do
      it "works and returns the correct key credential" do
        key = service.authenticate_security_key
        expect(key).to eq(security_key)
        expect(key.factor_type).to eq(UserSecurityKey.factor_types[:first_factor])
      end
    end

    context "when the user verification flag in the key is false" do
      it "raises a UserVerificationError" do
        # simulate missing user verification in the key data
        # by setting third bit to 0
        flags = "10000010" # correct flag sequence is "10100010"
        overridden_auth_data = service.send(:auth_data)
        overridden_auth_data[32] = [flags].pack("b*")

        service.instance_variable_set(:@auth_data, overridden_auth_data)

        expect { service.authenticate_security_key }.to raise_error(
          DiscourseWebauthn::UserVerificationError,
          I18n.t("webauthn.validation.user_verification_error"),
        )
      end
    end

    context "when the user handle does not match" do
      it "raises an OwnershipError" do
        params[:userHandle] = Base64.strict_encode64(SecureRandom.hex(20))

        expect { service.authenticate_security_key }.to raise_error(
          DiscourseWebauthn::OwnershipError,
          I18n.t("webauthn.validation.ownership_error"),
        )
      end
    end
  end
end
