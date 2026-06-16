# frozen_string_literal: true

module DiscourseAi
  module Completions
    # Registry of provider-native built-in tools.
    #
    # Unlike shipped/custom/MCP tools, these are executed server-side by the LLM
    # provider (e.g. Gemini Google Search grounding, OpenAI web search, Anthropic
    # web search). Discourse only declares them in the request payload; there is
    # no tool-call round-trip back to us. They are stored on an agent's `tools`
    # column with a "native-" prefix and rendered into the request by each
    # provider dialect.
    module NativeTools
      PREFIX = "native-"

      WEB_SEARCH = "web_search"
      WEB_FETCH = "web_fetch"

      # open_ai/azure only expose web search through the Responses API
      RESPONSES_API_PROVIDERS = %w[open_ai azure].freeze

      class Definition
        attr_reader :id, :providers

        def initialize(id:, providers:)
          @id = id
          @providers = providers
        end

        def name
          I18n.t("discourse_ai.ai_bot.native_tools.#{id}.name")
        end

        def help
          I18n.t("discourse_ai.ai_bot.native_tools.#{id}.help")
        end

        def supported?(llm_model)
          return false if llm_model.blank?

          provider = llm_model.provider
          return false if providers.exclude?(provider)

          if RESPONSES_API_PROVIDERS.include?(provider)
            return llm_model.url.to_s.include?("/v1/responses")
          end

          true
        end
      end

      DEFINITIONS = [
        Definition.new(id: WEB_SEARCH, providers: %w[google anthropic open_ai azure]),
        Definition.new(id: WEB_FETCH, providers: %w[google anthropic]),
      ].freeze

      def self.all
        DEFINITIONS
      end

      def self.find(id)
        id = strip_prefix(id)
        DEFINITIONS.find { |definition| definition.id == id }
      end

      def self.valid?(id)
        !find(id).nil?
      end

      # ids supported by a given LlmModel (encapsulates the Responses-API nuance)
      def self.supported_ids_for(llm_model)
        return [] if llm_model.blank?
        DEFINITIONS.select { |definition| definition.supported?(llm_model) }.map(&:id)
      end

      def self.prefixed?(name)
        name.is_a?(String) && name.start_with?(PREFIX)
      end

      def self.strip_prefix(name)
        return name unless prefixed?(name)
        name.delete_prefix(PREFIX)
      end
    end
  end
end
