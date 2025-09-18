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
end
