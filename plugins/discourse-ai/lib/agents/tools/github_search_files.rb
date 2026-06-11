# frozen_string_literal: true

module DiscourseAi
  module Agents
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

        MAX_FILE_SEARCH_RESULTS = 25

        def invoke
          # Fetch the default branch if no branch is specified
          branch_name = branch || fetch_default_branch(repo)
          @branch_name = branch_name

          api_url = "https://api.github.com/repos/#{repo}/git/trees/#{branch_name}?recursive=1"

          begin
            tree_data = github_client.get(api_url)
          rescue Discourse::GithubApi::Error => e
            return { error: "Failed to perform file search. #{e.message}" }
          end

          matching_files =
            tree_data["tree"]
              .select do |item|
                item["type"] == "blob" && keywords.any? { |keyword| item["path"].include?(keyword) }
              end
              .map { |item| { path: item["path"], size: item["size"] } }
              .take(MAX_FILE_SEARCH_RESULTS)

          result = { matching_files: matching_files, branch: branch_name }
          if matching_files.length == MAX_FILE_SEARCH_RESULTS
            result[
              :note
            ] = "Result limit reached (#{MAX_FILE_SEARCH_RESULTS} files). There may be more matching files."
          end
          result
        end
      end
    end
  end
end
