# frozen_string_literal: true

module DiscourseId
  module Concerns
    module ChallengeFlow
      extend ActiveSupport::Concern

      private

      def request_challenge
        response =
          post_json(
            "/challenge",
            { domain: Discourse.current_hostname }.tap do |body|
              body[:path] = Discourse.base_path if Discourse.base_path.present?
            end,
          )

        return fail!(response[:error]) if response[:error]

        json = response[:data]

        if json["domain"] != Discourse.current_hostname
          error =
            "Domain mismatch in challenge response (expected: #{Discourse.current_hostname}, got: #{json["domain"]})"
          log_error("request_challenge", error)
          return fail!(error)
        end

        if Discourse.base_path.present? && json["path"] != Discourse.base_path
          error =
            "Path mismatch in challenge response (expected: #{Discourse.base_path}, got: #{json["path"]})"
          log_error("request_challenge", error)
          return fail!(error)
        end

        context[:token] = json["token"]
      end

      def store_challenge_token(token:)
        Discourse.redis.setex("discourse_id_challenge_token", 600, token)
      end

      def post_json(path, body)
        uri = URI("#{discourse_id_url}#{path}")
        use_ssl = Rails.env.production? || uri.scheme == "https"

        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request.body = body.to_json

        begin
          response =
            Net::HTTP.start(uri.hostname, uri.port, use_ssl:) { |http| http.request(request) }
        rescue StandardError => e
          error = "Request to '#{uri}' failed: #{e.message}."
          log_error(path, error)
          return { error: }
        end

        if response.code.to_i != 200
          error = "Request to '#{path}' failed: #{response.code}\nError: #{response.body}"
          log_error(path, error)
          return { error: }
        end

        begin
          { data: JSON.parse(response.body) }
        rescue JSON::ParserError => e
          error = "Response from '#{path}' invalid JSON: #{e.message}"
          log_error(path, error)
          { error: }
        end
      end

      def discourse_id_url
        @discourse_id_url ||= DiscourseId.provider_url
      end

      def log_error(step, message)
        Rails.logger.error(
          "Discourse ID #{service_name} failed at step '#{step}'. Error: #{message}",
        )
      end

      def service_name
        self.class.name.demodulize.underscore.humanize.downcase
      end
    end
  end
end
