# frozen_string_literal: true
module DiscourseAi
  module Personas
    module Tools
      class GithubFileContent < Tool
        def self.signature
          {
            name: name,
            description: "Retrieves the content of specified GitHub files",
            parameters: [
              {
                name: "repo_name",
                description: "The name of the GitHub repository (e.g., 'discourse/discourse')",
                type: "string",
                required: true,
              },
              {
                name: "file_paths",
                description: "The paths of the files to retrieve within the repository",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "branch",
                description:
                  "The branch or commit SHA to retrieve the files from (default: 'main')",
                type: "string",
                required: false,
              },
            ],
          }
        end

        def self.name
          "github_file_content"
        end

        def repo_name
          parameters[:repo_name]
        end

        def file_paths
          parameters[:file_paths]
        end

        def branch
          parameters[:branch] || "main"
        end

        def description_args
          { repo_name: repo_name, file_paths: file_paths.join(", "), branch: branch }
        end

        def invoke
          owner, repo = repo_name.split("/")
          file_contents = {}
          missing_files = []

          file_paths.each do |file_path|
            api_url =
              "https://api.github.com/repos/#{owner}/#{repo}/contents/#{file_path}?ref=#{branch}"

            response_code = "-1 unknown"
            body = nil

            send_http_request(
              api_url,
              headers: {
                "Accept" => "application/vnd.github.v3+json",
              },
              authenticate_github: true,
            ) do |response|
              response_code = response.code
              body = read_response_body(response)
            end

            if response_code == "200"
              file_data = JSON.parse(body)
              content = Base64.decode64(file_data["content"])
              file_contents[file_path] = content
            else
              missing_files << file_path
            end
          end

          result = {}
          unless file_contents.empty?
            blob =
              file_contents.map { |path, content| "File Path: #{path}:\n#{content}" }.join("\n")
            truncated_blob = truncate(blob, max_length: 20_000, percent_length: 0.3, llm: llm)
            result[:file_contents] = truncated_blob
          end

          result[:missing_files] = missing_files unless missing_files.empty?

          result.empty? ? { error: "No files found or retrieved." } : result
        end
      end
    end
  end
end
