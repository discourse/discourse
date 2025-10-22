# frozen_string_literal: true

RSpec.describe DiscourseWebauthn::ChallengeGenerator do
  it "generates a DiscourseWebauthn::ChallengeGenerator::ChallengeSession with a challenge" do
    session = DiscourseWebauthn::ChallengeGenerator.generate
    expect(session).to be_a(DiscourseWebauthn::ChallengeGenerator::ChallengeSession)
    expect(session.challenge).not_to eq(nil)
  end

  describe "ChallengeSession" do
    describe "#commit_to_session" do
      let(:user) { Fabricate(:user) }
      let(:server_session) { ServerSession.new("some-prefix") }
      let(:generated_session) { DiscourseWebauthn::ChallengeGenerator.generate }

      it "stores the challenge in the provided session object" do
        generated_session.commit_to_session(server_session, user)

        expect(server_session["staged-webauthn-challenge-#{user&.id}"]).to eq(
          generated_session.challenge,
        )
      end
    end
  end
end
