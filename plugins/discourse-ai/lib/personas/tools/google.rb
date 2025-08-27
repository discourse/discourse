# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Google < Tool
        def self.signature
          {
            name: name,
            description:
              "Will search using Google - global internet search (supports all Google search operators)",
            parameters: [
              { name: "query", description: "The search query", type: "string", required: true },
            ],
          }
        end

        def self.custom_system_message
          "You were trained on OLD data, lean on search to get up to date information from the web"
        end

        def self.name
          "google"
        end

        def self.accepted_options
          [option(:base_query, type: :string)]
        end

        def query
          parameters[:query].to_s.strip
        end

        def invoke
          query = self.query

          yield(query)

          api_key = SiteSetting.ai_google_custom_search_api_key
          cx = SiteSetting.ai_google_custom_search_cx

          query = "#{options[:base_query]} #{query}" if options[:base_query].present?

          escaped_query = CGI.escape(query)
          uri =
            URI(
              "https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{escaped_query}&num=10",
            )

          body = Net::HTTP.get(uri)

          parse_search_json(body, escaped_query, llm)
        end

        attr_reader :results_count

        protected

        def description_args
          {
            count: results_count || 0,
            query: query,
            url: "https://google.com/search?q=#{CGI.escape(query)}",
          }
        end

        private

        def minimize_field(result, field, llm, max_tokens: 100)
          data = result[field]
          return "" if data.blank?

          llm
            .tokenizer
            .truncate(data, max_tokens, strict: SiteSetting.ai_strict_token_counting)
            .squish
        end

        def parse_search_json(json_data, escaped_query, llm)
          parsed = JSON.parse(json_data)
          error_code = parsed.dig("error", "code")
          if error_code == 429
            Rails.logger.warn(
              "Google Custom Search is Rate Limited, no search can be performed at the moment. #{json_data[0..1000]}",
            )
            return(
              "Google Custom Search is Rate Limited, no search can be performed at the moment. Let the user know there is a problem."
            )
          elsif error_code
            Rails.logger.warn("Google Custom Search returned an error. #{json_data[0..1000]}")
            return "Google Custom Search returned an error. Let the user know there is a problem."
          end

          results = parsed["items"]

          @results_count = parsed.dig("searchInformation", "totalResults").to_i

          format_results(results, args: escaped_query) do |result|
            {
              title: minimize_field(result, "title", llm),
              link: minimize_field(result, "link", llm),
              snippet: minimize_field(result, "snippet", llm, max_tokens: 120),
              displayLink: minimize_field(result, "displayLink", llm),
              formattedUrl: minimize_field(result, "formattedUrl", llm),
            }
          end
        end
      end
    end
  end
end
