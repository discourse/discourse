# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class OAuthTokenStore
      def initialize(server)
        @server = server
      end

      def access_token
        record&.access_token
      end

      def refresh_token
        record&.refresh_token
      end

      def write!(access_token:, refresh_token:)
        oauth_token = record || server.build_oauth_token
        oauth_token.access_token = access_token unless access_token.nil?
        oauth_token.refresh_token = refresh_token unless refresh_token.nil?

        if oauth_token.access_token.blank? && oauth_token.refresh_token.blank?
          oauth_token.destroy! if oauth_token.persisted?
        else
          oauth_token.save!
        end

        reset_association_cache
      end

      def clear!
        record&.destroy!
        reset_association_cache
      end

      private

      attr_reader :server

      def record
        server.oauth_token
      end

      def reset_association_cache
        server.association(:oauth_token).reset
      end
    end
  end
end
