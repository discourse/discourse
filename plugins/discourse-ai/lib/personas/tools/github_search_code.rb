# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class GithubSearchCode < Tool
        def self.signature
          {
            name: name,
            description: "Searches for code in a GitHub repository",
            parameters: [
              {
                name: "repo",
                description: "The repository name in the format 'owner/repo'",
                type: "string",
                required: true,
              },
              {
                name: "query",
                description: "The search query (e.g., a function name, variable, or code snippet)",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "github_search_code"
        end

        def repo
          parameters[:repo]
        end

        def query
          parameters[:query]
        end

        def description_args
          { repo: repo, query: query }
        end

        def invoke
          api_url = "https://api.github.com/search/code?q=#{query}+repo:#{repo}"

          response_code = "unknown error"
          search_data = nil

          send_http_request(
            api_url,
            headers: {
              "Accept" => "application/vnd.github.v3.text-match+json",
            },
            authenticate_github: true,
          ) do |response|
            response_code = response.code
            if response_code == "200"
              begin
                search_data = JSON.parse(read_response_body(response))
              rescue JSON::ParserError
                response_code = "500 - JSON parse error"
              end
            end
          end

          if response_code == "200"
            results =
              search_data["items"]
                .map { |item| "#{item["path"]}:\n#{item["text_matches"][0]["fragment"]}" }
                .join("\n---\n")

            results = truncate(results, max_length: 20_000, percent_length: 0.3, llm: llm)
            { search_results: results }
          else
            { error: "Failed to perform code search. Status code: #{response_code}" }
          end
        end
      end
    end
  end
end
