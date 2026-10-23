# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    # A custom tool searched as an Ask AI source. The pipeline calls it with the
    # asked and prepared queries, rather than a model choosing to, and its
    # results are ranked with the forum's and shown as cards, so every tool
    # returns the same shape:
    #
    #   [{ title:, url:, blurb:, content:, published_at: }]
    #
    # title and an http(s) url are required. blurb is shown on the card,
    # content is what the model reads, and both are plain text.
    class ExternalSource
      KIND = "external"
      MAX_RESULTS = 10
      TITLE_LIMIT = 200
      BLURB_LIMIT = 300
      URL_LIMIT = 2000

      class InvalidResults < StandardError
      end

      class << self
        def configured(user:)
          ids = SiteSetting.ai_ask_ai_external_sources.to_s.split("|").map(&:to_i)
          return [] if ids.empty?

          AiTool
            .where(id: ids, enabled: true)
            .includes(:secret_bindings)
            .map { |ai_tool| new(ai_tool, user:) }
        end

        def configured?(ai_tool)
          ai_tool.id.present? &&
            SiteSetting.ai_ask_ai_external_sources.to_s.split("|").include?(ai_tool.id.to_s)
        end

        def candidate?(candidate)
          candidate["kind"] == KIND
        end

        # In strict mode, used when an admin tests a tool, a malformed result
        # fails loudly. Searches drop it and keep the rest.
        #
        # @return [Array<Hash>] the usable results, with string keys
        # @raise [InvalidResults] when the output is not a list of results, or
        #   any result is malformed in strict mode
        def normalize(output, strict: false)
          if !output.is_a?(Array)
            raise InvalidResults, I18n.t("discourse_ai.ask_ai.external_sources.invalid_output")
          end

          output
            .filter_map
            .with_index do |result, index|
              normalized = normalize_result(result)
              if normalized.nil? && strict
                raise InvalidResults,
                      I18n.t(
                        "discourse_ai.ask_ai.external_sources.invalid_result",
                        position: index + 1,
                      )
              end
              normalized
            end
            .first(MAX_RESULTS)
        end

        private

        def normalize_result(result)
          return if !result.is_a?(Hash)

          title = plain_text(result["title"], TITLE_LIMIT)
          url = http_url(result["url"])
          return if title.blank? || url.nil?

          content = plain_text(result["content"], Retrieval::EXCERPT_LIMIT)
          {
            "title" => title,
            "url" => url,
            "blurb" => plain_text(result["blurb"], BLURB_LIMIT),
            "content" => content,
            "published_at" => timestamp(result["published_at"]),
          }.compact_blank
        end

        def plain_text(value, limit)
          return if !value.is_a?(String)

          Nokogiri::HTML5.fragment(value).text.squish.first(limit)
        end

        def http_url(value)
          return if !value.is_a?(String) || value.length > URL_LIMIT

          uri = URI.parse(value.strip)
          uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
        rescue URI::InvalidURIError
          nil
        end

        def timestamp(value)
          Time.iso8601(value).utc.iso8601 if value.is_a?(String)
        rescue ArgumentError
          nil
        end
      end

      attr_reader :ai_tool

      def initialize(ai_tool, user:)
        @ai_tool = ai_tool
        @user = user
      end

      def name
        ai_tool.name
      end

      # @return [Array<Hash>] the source's results as retrieval candidates
      def call(query:, keyword_query:, semantic_query:, locale:)
        runner =
          ai_tool.runner(
            { query:, keyword_query:, semantic_query:, locale: },
            llm: nil,
            bot_user: Discourse.system_user,
            context: DiscourseAi::Agents::BotContext.new(user: @user, feature_name: "ask_ai"),
          )
        output = runner.invoke
        raise InvalidResults, output[:error].to_s if output.is_a?(Hash) && output[:error]

        self
          .class
          .normalize(output)
          .map do |result|
            result.except("content").merge(
              "kind" => KIND,
              "source_id" => ai_tool.id,
              "source_name" => name,
              # the model reads the excerpt, as it does a forum candidate's
              "excerpt" => result["content"] || result["blurb"],
            )
          end
      end
    end
  end
end
