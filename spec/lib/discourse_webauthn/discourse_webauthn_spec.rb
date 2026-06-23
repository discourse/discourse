# frozen_string_literal: true

RSpec.describe DiscourseWebauthn do
  fab!(:user)

  describe "#origin" do
    it "returns the current hostname" do
      expect(DiscourseWebauthn.origin).to eq("http://test.localhost")
    end

    context "with subfolder" do
      it "does not append /forum to origin" do
        set_subfolder "/forum"
        expect(DiscourseWebauthn.origin).to eq("http://test.localhost")
      end
    end
  end

  describe ".stage_challenge" do
    let(:server_session) { ServerSession.new("some-prefix") }

    it "stores the challenge in the provided session object with the right expiry" do
      described_class.stage_challenge(user, server_session)
      key = described_class.session_challenge_key(user)

      expect(server_session[key]).to be_present

      expect(server_session.ttl(key)).to be_within_one_second_of(
        DiscourseWebauthn::CHALLENGE_EXPIRY,
      )
    end
  end

  describe ".clear_challenge" do
    let(:server_session) { ServerSession.new("some-prefix") }

    it "clears the challenge from the provided session object" do
      described_class.stage_challenge(user, server_session)
      key = described_class.session_challenge_key(user)

      expect(server_session[key]).to be_present

      described_class.clear_challenge(user, server_session)

      expect(server_session[key]).to be_nil
    end
  end

  describe ".allowed_credentials" do
    let(:server_session) { ServerSession.new("some-prefix") }

    before do
      SiteSetting.allow_passkeys_for_2fa = true
      described_class.stage_challenge(user, server_session)
    end

    it "returns an empty hash when the user has no webauthn credentials" do
      expect(described_class.allowed_credentials(user, server_session)).to eq({})
    end

    it "returns only security key ids for a user with a security key" do
      key = Fabricate(:user_security_key_with_random_credential, user: user)
      response = described_class.allowed_credentials(user, server_session)

      expect(response[:allowed_credential_ids]).to contain_exactly(key.credential_id)
      expect(response).not_to have_key(:passkey_allowed_credential_ids)
      expect(response[:challenge]).to be_present
    end

    it "does not include passkeys unless include_passkeys is passed" do
      Fabricate(:passkey_with_random_credential, user: user)

      expect(described_class.allowed_credentials(user, server_session)).to eq({})
    end

    it "returns passkey ids separately from security key ids" do
      key = Fabricate(:user_security_key_with_random_credential, user: user)
      passkey = Fabricate(:passkey_with_random_credential, user: user)

      response = described_class.allowed_credentials(user, server_session, include_passkeys: true)

      expect(response[:allowed_credential_ids]).to contain_exactly(key.credential_id)
      expect(response[:passkey_allowed_credential_ids]).to contain_exactly(passkey.credential_id)
      expect(response[:challenge]).to be_present
    end

    it "does not include passkey ids when allow_passkeys_for_2fa is disabled" do
      SiteSetting.allow_passkeys_for_2fa = false
      Fabricate(:passkey_with_random_credential, user: user)

      expect(
        described_class.allowed_credentials(user, server_session, include_passkeys: true),
      ).to eq({})
    end
  end
end
