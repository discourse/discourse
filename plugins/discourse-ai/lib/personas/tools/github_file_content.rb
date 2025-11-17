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
                description:
                  "The file paths to retrieve. Append '#Lstart-Lend' (e.g., app/models/user.rb#L10-L25) to limit the returned lines",
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
          parameters[:branch]
        end

        def description_args
          {
            repo_name: repo_name,
            file_paths: file_paths.join(", "),
            branch: branch || default_branch,
          }
        end

        def invoke
          owner, repo = repo_name.split("/")
          ref = branch || default_branch
          retrieved_entries = []
          missing_files = []

          parsed_file_requests.each do |file_request|
            file_path = file_request[:path]
            api_url =
              "https://api.github.com/repos/#{owner}/#{repo}/contents/#{file_path}?ref=#{ref}"

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
              snippet =
                extract_requested_content(
                  content,
                  file_request[:start_line],
                  file_request[:end_line],
                )
              retrieved_entries << {
                path: file_path,
                content: snippet,
                start_line: file_request[:start_line],
                end_line: file_request[:end_line],
              }
            else
              missing_files << file_request[:raw]
            end
          end

          result = {}
          unless retrieved_entries.empty?
            blob =
              retrieved_entries
                .map do |entry|
                  label = "File Path: #{entry[:path]}"
                  if entry[:start_line]
                    label += " (lines #{format_line_range(entry[:start_line], entry[:end_line])})"
                  end

                  "#{label}:\n#{entry[:content]}"
                end
                .join("\n")
            truncated_blob = truncate(blob, max_length: 20_000, percent_length: 0.3, llm: llm)
            result[:file_contents] = truncated_blob
          end

          result[:missing_files] = missing_files unless missing_files.empty?

          result.empty? ? { error: "No files found or retrieved." } : result
        end

        private

        def default_branch
          @default_branch ||= fetch_default_branch(repo_name)
        end

        def parsed_file_requests
          @parsed_file_requests ||=
            file_paths.map do |raw|
              start_line, end_line = extract_line_bounds(raw)

              {
                raw: raw,
                path: raw.sub(line_fragment_regex, ""),
                start_line: start_line,
                end_line: end_line || start_line,
              }
            end
        end

        def extract_line_bounds(raw)
          match = raw.match(line_fragment_regex)
          return nil, nil unless match

          start_line = positive_line_number(match[1])
          end_line = positive_line_number(match[2])
          end_line = start_line if start_line && end_line && end_line < start_line

          [start_line, end_line]
        end

        def positive_line_number(value)
          return if value.blank?

          number = value.to_i
          number.positive? ? number : nil
        end

        def line_fragment_regex
          /#L(\d+)(?:-L?(\d+))?\z/i
        end

        def extract_requested_content(content, start_line, end_line)
          return content if start_line.nil?

          normalized = content.gsub("\r\n", "\n")
          lines = normalized.split("\n")
          total_lines = lines.length

          if start_line > total_lines
            return(
              "Requested lines #{start_line}-#{end_line || start_line} exceed file length of #{total_lines}."
            )
          end

          final_end_line = [end_line || start_line, total_lines].min
          extracted = lines[(start_line - 1)..(final_end_line - 1)] || []
          extracted.join("\n")
        end

        def format_line_range(start_line, end_line)
          return start_line.to_s if start_line == end_line || end_line.nil?

          "#{start_line}-#{end_line}"
        end
      end
    end
  end
end
