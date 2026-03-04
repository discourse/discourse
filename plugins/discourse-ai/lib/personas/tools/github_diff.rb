# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class GithubDiff < Tool
        LARGE_OBJECT_THRESHOLD = 30_000

        def self.signature
          {
            name: name,
            description: "Retrieves the diff for a GitHub pull request or commit",
            parameters: [
              {
                name: "repo",
                description: "The repository name in the format 'owner/repo'",
                type: "string",
                required: true,
              },
              {
                name: "pull_id",
                description: "The pull request number (use this OR sha, not both)",
                type: "integer",
                required: false,
              },
              {
                name: "sha",
                description: "The commit SHA (use this OR pull_id, not both)",
                type: "string",
                required: false,
              },
            ],
          }
        end

        def self.name
          "github_diff"
        end

        def repo
          parameters[:repo]
        end

        def pull_id
          parameters[:pull_id]
        end

        def sha
          parameters[:sha]
        end

        def url
          @url
        end

        def invoke
          return { error: "Must provide either pull_id or sha" } if pull_id.blank? && sha.blank?

          # Prioritize sha if present (LLMs sometimes pass both)
          sha.present? ? fetch_commit : fetch_pull_request
        end

        def description_args
          if sha.present?
            { repo: repo, ref: sha, url: url }
          else
            { repo: repo, ref: pull_id, url: url }
          end
        end

        def self.sort_and_shorten_diff(diff, threshold: LARGE_OBJECT_THRESHOLD)
          file_start_regex = /^diff --git.*/

          prev_start = -1
          prev_match = nil

          split = []

          diff.scan(file_start_regex) do |match|
            match_start = $~.offset(0)[0]

            if prev_start != -1
              full_diff = diff[prev_start...match_start]
              split << [prev_match, full_diff]
            end

            prev_match = match
            prev_start = match_start
          end

          split << [prev_match, diff[prev_start..-1]] if prev_match

          split.sort! { |x, y| x[1].length <=> y[1].length }

          split
            .map do |x, y|
              if y.length < threshold
                y
              else
                "#{x}\nRedacted, Larger than #{threshold} chars"
              end
            end
            .join("\n")
        end

        private

        def fetch_pull_request
          api_url = "https://api.github.com/repos/#{repo}/pulls/#{pull_id}"
          @url = "https://github.com/#{repo}/pull/#{pull_id}"

          fetch_diff(api_url, "PR") do |info, diff|
            source_repo = info.dig("head", "repo", "full_name")
            source_branch = info.dig("head", "ref")
            source_sha = info.dig("head", "sha")
            target_repo = info.dig("base", "repo", "full_name")
            target_branch = info.dig("base", "ref")

            {
              type: "pull_request",
              diff: diff,
              pr_info: {
                title: info["title"],
                state: info["state"],
                source: {
                  repo: source_repo,
                  branch: source_branch,
                  sha: source_sha,
                  url: "https://github.com/#{source_repo}/tree/#{source_branch}",
                },
                target: {
                  repo: target_repo,
                  branch: target_branch,
                },
                author: info.dig("user", "login"),
                created_at: info["created_at"],
                updated_at: info["updated_at"],
              },
            }
          end
        end

        def fetch_commit
          api_url = "https://api.github.com/repos/#{repo}/commits/#{sha}"
          @url = "https://github.com/#{repo}/commit/#{sha}"

          fetch_diff(api_url, "commit") do |info, diff|
            {
              type: "commit",
              diff: diff,
              commit_info: {
                sha: info["sha"],
                message: info.dig("commit", "message"),
                author: info.dig("commit", "author", "name"),
                author_login: info.dig("author", "login"),
                date: info.dig("commit", "author", "date"),
                url: @url,
                stats: {
                  additions: info.dig("stats", "additions"),
                  deletions: info.dig("stats", "deletions"),
                  total: info.dig("stats", "total"),
                },
                files_changed: info["files"]&.length || 0,
              },
            }
          end
        end

        def fetch_diff(api_url, type)
          info = nil
          diff_body = nil
          response_code = "unknown error"

          send_http_request(
            api_url,
            headers: {
              "Accept" => "application/json",
            },
            authenticate_github: true,
          ) do |response|
            response_code = response.code
            info = JSON.parse(read_response_body(response)) if response_code == "200"
          end

          if response_code == "200"
            send_http_request(
              api_url,
              headers: {
                "Accept" => "application/vnd.github.v3.diff",
              },
              authenticate_github: true,
            ) do |response|
              response_code = response.code
              diff_body = read_response_body(response)
            end
          end

          if response_code == "200" && info && diff_body
            diff = self.class.sort_and_shorten_diff(diff_body)
            diff = truncate(diff, max_length: 20_000, percent_length: 0.3, llm: llm)
            yield(info, diff)
          else
            { error: "Failed to retrieve the #{type} information. Status code: #{response_code}" }
          end
        end
      end
    end
  end
end
