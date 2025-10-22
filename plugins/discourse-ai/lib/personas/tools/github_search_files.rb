# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class GithubSearchFiles < Tool
        def self.signature
          {
            name: name,
            description:
              "Searches for files in a GitHub repository containing specific keywords in their paths or names",
            parameters: [
              {
                name: "repo",
                description: "The repository name in the format 'owner/repo'",
                type: "string",
                required: true,
              },
              {
                name: "keywords",
                description: "An array of keywords to match in file paths or names",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "branch",
                description:
                  "The branch or commit SHA to search within (default: repository's default branch)",
                type: "string",
                required: false,
              },
            ],
          }
        end

        def self.name
          "github_search_files"
        end

        def repo
          parameters[:repo]
        end

        def keywords
          parameters[:keywords]
        end

        def branch
          parameters[:branch]
        end

        def description_args
          { repo: repo, keywords: keywords.join(", "), branch: @branch_name }
        end

        def invoke
          # Fetch the default branch if no branch is specified
          branch_name = branch || fetch_default_branch(repo)
          @branch_name = branch_name

          api_url = "https://api.github.com/repos/#{repo}/git/trees/#{branch_name}?recursive=1"

          response_code = "unknown error"
          tree_data = nil

          send_http_request(
            api_url,
            headers: {
              "Accept" => "application/vnd.github.v3+json",
            },
            authenticate_github: true,
          ) do |response|
            response_code = response.code
            if response_code == "200"
              begin
                tree_data = JSON.parse(read_response_body(response))
              rescue JSON::ParserError
                response_code = "500 - JSON parse error"
              end
            end
          end

          if response_code == "200"
            matching_files =
              tree_data["tree"]
                .select do |item|
                  item["type"] == "blob" &&
                    keywords.any? { |keyword| item["path"].include?(keyword) }
                end
                .map { |item| item["path"] }

            { matching_files: matching_files, branch: branch_name }
          else
            { error: "Failed to perform file search. Status code: #{response_code}" }
          end
        end
      end
    end
  end
end
