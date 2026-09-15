# frozen_string_literal: true

module Voice
  module Livekit
    # Read-only catalogue of the agents deployed to the LiveKit Cloud project,
    # so inviters can pick a dispatch name instead of typing one. Cloud-only:
    # self-hosted servers have no catalogue, and workers running outside
    # LiveKit's hosting never appear in it, so callers must keep a typed-name
    # path.
    class CloudAgentClient
      CACHE_KEY = "voice:livekit:cloud_agents"
      CACHE_TTL = 1.minute
      TIMEOUT_SECONDS = 5

      # The catalogue API refuses requests that do not identify a CLI version.
      # This is the version whose response shape `parse` follows.
      CLIENT_VERSION = "2.18.6"

      def self.list
        return { ok: false } unless Livekit.cloud? && Livekit.configured?

        cached = Discourse.redis.get(CACHE_KEY)
        return { ok: true, agents: JSON.parse(cached, symbolize_names: true) } if cached

        response =
          Twirp.post(
            service: "CloudAgent",
            method: "ListAgents",
            body: {
            },
            claims: {
              agent: {
                admin: true,
              },
            },
            headers: {
              "X-LIVEKIT-CLI-VERSION" => CLIENT_VERSION,
            },
            base_url:,
            timeout: TIMEOUT_SECONDS,
          )

        unless response.status == 200
          Rails.logger.warn("[voice-livekit] ListAgents failed: HTTP #{response.status}")
          return { ok: false }
        end

        agents = parse(response.body)
        Discourse.redis.setex(CACHE_KEY, CACHE_TTL.to_i, agents.to_json)
        { ok: true, agents: }
      rescue StandardError => error
        Rails.logger.warn("[voice-livekit] ListAgents failed: #{error.class}")
        { ok: false }
      end

      def self.clear_cache!
        Discourse.redis.del(CACHE_KEY)
      end

      # Deployed agents are catalogued on LiveKit's shared agents host, not on
      # the project's own subdomain that serves the SFU and dispatch APIs.
      def self.base_url
        Twirp.api_base_url.sub(%r{\Ahttps://[a-zA-Z0-9\-]+\.}, "https://agents.")
      end

      # Agents still being created have no dispatch name yet and cannot be
      # invited, so they are left out.
      def self.parse(body)
        JSON
          .parse(body)
          .fetch("agents", [])
          .filter_map do |agent|
            name = (agent["agent_name"] || agent["agentName"]).to_s.strip
            { name: } if name.present?
          end
          .uniq
          .sort_by { |agent| agent[:name] }
      end
      private_class_method :parse
    end
  end
end
