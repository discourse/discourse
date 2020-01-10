# frozen_string_literal: true
module Webauthn
  class ChallengeGenerator
    class ChallengeSession
      attr_reader :challenge, :rp_id, :rp_name

      def initialize(params)
        @challenge = params[:challenge]
        @rp_id = params[:rp_id]
        @rp_name = params[:rp_name]
      end

      def commit_to_session(secure_session, user)
        secure_session[self.class.session_challenge_key(user)] = @challenge
        secure_session[self.class.session_rp_id_key(user)] = @rp_id
        secure_session[self.class.session_rp_name_key(user)] = @rp_name

        self
      end

      def self.session_challenge_key(user)
        "staged-webauthn-challenge-#{user&.id}"
      end

      def self.session_rp_id_key(user)
        "staged-webauthn-rp-id-#{user&.id}"
      end

      def self.session_rp_name_key(user)
        "staged-webauthn-rp-name-#{user&.id}"
      end
    end

    def self.generate
      ChallengeSession.new(
        challenge: SecureRandom.hex(30),
        rp_id: Discourse.current_hostname,
        rp_name: SiteSetting.title
      )
    end
  end
end
