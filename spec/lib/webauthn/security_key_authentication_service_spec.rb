# frozen_string_literal: true
require 'rails_helper'
require 'webauthn'
require 'webauthn/security_key_registration_service'

describe Webauthn::SecurityKeyAuthenticationService do
  let(:security_key_user) { current_user }
  let(:security_key) do
    Fabricate(
      :user_security_key,
      credential_id: 'mJAJ4CznTO0SuLkJbYwpgK75ao4KMNIPlU5KWM92nq39kRbXzI9mSv6GxTcsMYoiPgaouNw7b7zBiS4vsQaO6A==',
      public_key: 'pQECAyYgASFYIMNgw4GCpwBUlR2SznJ1yY7B9yFvsuxhfo+C9kcA4IitIlggRdofrCezymy2B/YarX+gfB6gZKg648/cHIMjf6wWmmU=',
      user: security_key_user,
      last_used: nil
    )
  end
  let(:credential_id) { security_key.credential_id }
  let(:challenge) { '81d4acfbd69eafa8f02bc2ecbec5267be8c9b28c1e0ba306d52b79f0f13d' }
  let(:client_data_challenge) { Base64.strict_encode64(challenge) }
  let(:client_data_webauthn_type) { 'webauthn.get' }
  let(:client_data_origin) { 'http://localhost:3000' }

  ##
  # IMPORTANT: For the SHA256 hash to match the same one as was used to generate
  # the values for this spec, the three keys and values must be in the same order
  # (challenge, origin, type)
  let(:client_data_param) {
    {
      challenge: client_data_challenge,
      origin: client_data_origin,
      type: client_data_webauthn_type
    }
  }
  ##
  # These are sourced from an actual login using the UserSecurityKey credential
  # defined in this spec.
  let(:signature) { "MEUCIBppPyK8blxBDoktU54mI1vWEY96r1V5H1rEBtPDxwcGAiEAoi7LCmMoEAuWYu0krZpflZlULsbURCGcqOwP06amXYE=" }
  let(:authenticator_data) { "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAAVw==" }
  let(:params) do
    {
      clientData: Base64.strict_encode64(client_data_param.to_json),
      credentialId: credential_id,
      authenticatorData: authenticator_data,
      signature: signature
    }
  end
  ##
  # The original key was generated in localhost
  let(:rp_id) { 'localhost' }
  let(:challenge_params) do
    {
      challenge: challenge,
      rp_id: rp_id,
      origin: 'http://localhost:3000'
    }
  end
  let(:current_user) { Fabricate(:user) }
  let(:subject) { described_class.new(current_user, params, challenge_params) }

  it 'updates last_used when valid' do
    subject.authenticate_security_key
    expect(security_key.reload.last_used).not_to eq(nil)
  end

  context "when params is blank" do
    let(:params) { nil }
    it "returns false with no validation" do
      expect(subject.authenticate_security_key).to eq(false)
    end
  end

  context "when params is not blank and not a hash" do
    let(:params) { 'test' }
    it "returns false with no validation" do
      expect(subject.authenticate_security_key).to eq(false)
    end
  end

  context 'when the credential ID does not match any user security key in the database' do
    let(:credential_id) { 'badid' }

    it 'raises a NotFoundError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::NotFoundError, I18n.t('webauthn.validation.not_found_error')
      )
    end
  end

  context 'when the credential ID does exist but it is for a different user' do
    let(:security_key_user) { Fabricate(:user) }

    it 'raises an OwnershipError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::OwnershipError, I18n.t('webauthn.validation.ownership_error')
      )
    end
  end

  context 'when the client data webauthn type is not webauthn.get' do
    let(:client_data_webauthn_type) { 'webauthn.explode' }

    it 'raises an InvalidTypeError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::InvalidTypeError, I18n.t('webauthn.validation.invalid_type_error')
      )
    end
  end

  context 'when the decoded challenge does not match the original challenge provided by the server' do
    let(:client_data_challenge) { Base64.strict_encode64('invalid challenge') }

    it 'raises a ChallengeMismatchError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::ChallengeMismatchError, I18n.t('webauthn.validation.challenge_mismatch_error')
      )
    end
  end

  context 'when the origin of the client data does not match the server origin' do
    let(:client_data_origin) { 'https://someothersite.com' }

    it 'raises a InvalidOriginError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::InvalidOriginError, I18n.t('webauthn.validation.invalid_origin_error')
      )
    end
  end

  context 'when the sha256 hash of the relaying party ID does not match the one in attestation.authData' do
    let(:rp_id) { 'bad_rp_id' }

    it 'raises a InvalidRelyingPartyIdError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::InvalidRelyingPartyIdError, I18n.t('webauthn.validation.invalid_relying_party_id_error')
      )
    end
  end

  context 'when there is a problem verifying the public key (e.g. invalid signature)' do
    let(:signature) { Base64.strict_encode64('badsig') }

    it 'raises a PublicKeyError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::PublicKeyError, I18n.t('webauthn.validation.public_key_error')
      )
    end
  end

  context 'when the COSE algorithm used cannot be found' do
    before do
      COSE::Algorithm.expects(:find).returns(nil)
    end

    it 'raises a UnknownCOSEAlgorithmError' do
      expect { subject.authenticate_security_key }.to raise_error(
        Webauthn::UnknownCOSEAlgorithmError, I18n.t('webauthn.validation.unknown_cose_algorithm_error')
      )
    end
  end
end
