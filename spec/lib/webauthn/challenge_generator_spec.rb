# frozen_string_literal: true

require 'rails_helper'

describe Webauthn::ChallengeGenerator do
  it "generates a Webauthn::ChallengeGenerator::ChallengeSession with correct params" do
    session = Webauthn::ChallengeGenerator.generate
    expect(session).to be_a(Webauthn::ChallengeGenerator::ChallengeSession)
    expect(session.challenge).not_to eq(nil)
    expect(session.rp_id).to eq(Discourse.current_hostname)
    expect(session.rp_name).to eq(SiteSetting.title)
  end

  describe "ChallengeSession" do
    describe "#commit_to_session" do
      let(:user) { Fabricate(:user) }

      it "stores the challenge, rpid, and name in the provided session object" do
        secure_session = {}
        generated_session = Webauthn::ChallengeGenerator.generate
        generated_session.commit_to_session(secure_session, user)

        expect(secure_session["staged-webauthn-challenge-#{user&.id}"]).to eq(generated_session.challenge)
        expect(secure_session["staged-webauthn-rp-id-#{user&.id}"]).to eq(generated_session.rp_id)
        expect(secure_session["staged-webauthn-rp-name-#{user&.id}"]).to eq(generated_session.rp_name)
      end
    end
  end
end
