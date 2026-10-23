# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class ProviderPausedError < StandardError
      def initialize
        super("Embedding provider is temporarily paused")
      end
    end

    class ProviderHealth
      PAUSE_BACKOFFS = [30.seconds, 3.minutes, 20.minutes, 1.hour, 6.hours].freeze
      BACKOFF_STATE_TTL = 1.day
      MIN_RATE_LIMIT_PAUSE = 30.seconds

      class << self
        def paused?(definition)
          definition&.persisted? && Discourse.redis.exists?(pause_key(definition.id))
        end

        def request!(definition)
          state = provider_state(definition)
          raise ProviderPausedError if state&.first

          result = yield
          Discourse.redis.del(backoff_key(definition.id)) if state&.last
          result
        rescue DiscourseAi::Inference::EmbeddingInferenceError => error
          note_failure!(definition, error)
          raise
        end

        def clear!(definition_or_id)
          id = definition_or_id.respond_to?(:id) ? definition_or_id.id : definition_or_id
          Discourse.redis.del(pause_key(id), backoff_key(id)) if id.present?
        end

        private

        def provider_state(definition)
          return if !definition&.persisted?

          Discourse.redis.mget(pause_key(definition.id), backoff_key(definition.id))
        end

        def note_failure!(definition, error)
          return if !definition&.persisted?
          return pause!(definition, error) if error.terminal?
          return if !error.rate_limited?

          hold!(definition, error, error.retry_after.to_i.clamp(MIN_RATE_LIMIT_PAUSE.to_i..))
        end

        def pause!(definition, error)
          level = [
            Discourse.redis.get(backoff_key(definition.id)).to_i,
            PAUSE_BACKOFFS.length - 1,
          ].min
          hold!(definition, error, PAUSE_BACKOFFS[level].to_i, mode: :overwrite)

          Discourse.redis.set(
            backoff_key(definition.id),
            [level + 1, PAUSE_BACKOFFS.length - 1].min,
            ex: BACKOFF_STATE_TTL.to_i,
          )
        end

        def hold!(definition, error, ttl, mode: :if_absent)
          paused =
            Discourse.redis.set(
              pause_key(definition.id),
              error.category.to_s,
              nx: mode == :if_absent,
              ex: ttl,
            )
          return if !paused

          Rails.logger.warn(
            "Discourse AI embedding provider paused definition_id=#{definition.id} " \
              "provider=#{definition.provider} category=#{error.category} " \
              "duration=#{ttl}s status=#{error.http_status.inspect} " \
              "code=#{error.provider_error_code.inspect}",
          )
        end

        def pause_key(id)
          "discourse_ai:embedding_provider_paused:#{id}"
        end

        def backoff_key(id)
          "discourse_ai:embedding_provider_backoff:#{id}"
        end
      end
    end
  end
end
