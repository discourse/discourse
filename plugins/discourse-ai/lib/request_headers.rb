# frozen_string_literal: true

module DiscourseAi
  # Lets plugins add per-request HTTP headers (e.g. routing hints for a proxy) to
  # outbound model requests without reaching into endpoint internals.
  module RequestHeaders
    # `model` is the LlmModel or DecisionModel the request is for.
    Context =
      Struct.new(
        :model,
        :feature_name,
        :feature_context,
        :has_images,
        :streaming,
        keyword_init: true,
      )

    # Mutated in place (<<, clear) but never reassigned.
    PROVIDERS = []

    class << self
      # The block receives a Context and returns a Hash of headers.
      def register(&block)
        PROVIDERS << block
      end

      # Provider failures are logged and skipped so a header bug can never break
      # a request.
      # @param context [Context]
      # @return [Hash{String => String}]
      def for(context)
        PROVIDERS.each_with_object({}) do |provider, headers|
          result = provider.call(context)
          headers.merge!(result.stringify_keys) if result.is_a?(Hash)
        rescue StandardError => e
          Discourse.warn_exception(
            e,
            message: "Discourse AI request header provider raised an error; skipping it",
          )
        end
      end

      def reset!
        PROVIDERS.clear
      end
    end
  end
end
