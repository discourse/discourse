# frozen_string_literal: true
module DiscourseWebauthn
  class ChallengeGenerator
    class ChallengeSession
      attr_reader :challenge

      def initialize(params)
        @challenge = params[:challenge]
      end

      def commit_to_session(secure_session, user, expires: nil)
        secure_session.set(DiscourseWebauthn.session_challenge_key(user), @challenge, expires:)
        self
      end
    end

    def self.generate
      ChallengeSession.new(challenge: SecureRandom.hex(30))
    end
  end
end
