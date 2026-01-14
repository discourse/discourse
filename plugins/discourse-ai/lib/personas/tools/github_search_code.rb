# frozen_string_literal: true

require "cgi"
require "uri"

module DiscourseAi
  module Personas
    module Tools
      class GithubSearchCode < Tool
        MAX_GH_RESULTS = 1_000
        PER_PAGE = 30
        MAX_ALLOWED_PAGE = (MAX_GH_RESULTS / PER_PAGE.to_f).ceil

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
              {
                name: "page",
                description: "Results page to retrieve (GitHub returns up to 30 results per page)",
                type: "integer",
                required: false,
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

        def page
          requested = parameters[:page].to_i
          requested = 1 if requested <= 0
          [requested, MAX_ALLOWED_PAGE].min
        end

        def description_args
          { repo: repo, query: query, page: page }
        end

        def invoke
          api_url = build_url

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
            formatted_results = trim_results(format_results(search_data["items"]))

            total_count = search_data["total_count"].to_i
            total_pages =
              if total_count <= 0
                1
              else
                [((total_count.to_f / PER_PAGE).ceil), MAX_ALLOWED_PAGE].min
              end

            result = {
              search_results: formatted_results,
              pagination: {
                current_page: page,
                per_page: PER_PAGE,
                total_count: total_count,
                total_pages: total_pages,
                has_next_page: page < total_pages,
                next_page: page < total_pages ? page + 1 : nil,
                has_previous_page: page > 1,
                previous_page: page > 1 ? page - 1 : nil,
              },
            }

            if search_data["incomplete_results"]
              result[:notes] = "GitHub marked the search results as incomplete."
            end

            result
          else
            { error: "Failed to perform code search. Status code: #{response_code}" }
          end
        end

        private

        def build_url
          base_query = "#{query} repo:#{repo}"
          encoded_params = URI.encode_www_form({ q: base_query, page: page, per_page: PER_PAGE })

          "https://api.github.com/search/code?#{encoded_params}"
        end

        def format_results(items)
          return [] if items.blank?

          file_cache = {}

          results =
            items.flat_map do |item|
              text_matches = item["text_matches"]
              next [] if text_matches.blank?

              repo_full_name = item.dig("repository", "full_name") || repo
              path = item["path"]
              ref =
                extract_ref(item) || item.dig("repository", "default_branch") ||
                  fetch_default_branch(repo_full_name)
              sha = item["sha"]

              file_details = fetch_file_content(repo_full_name, path, ref, file_cache, sha)

              text_matches.map do |match|
                fragment = match["fragment"]
                next if fragment.blank?

                content = file_details&.dig(:content)
                total_lines = file_details&.dig(:total_lines)
                line_range = derive_line_range(content, fragment)

                {
                  file: path,
                  lines: format_line_label(line_range),
                  total_file_lines: total_lines,
                  content: fragment,
                }
              end
            end

          results.compact
        end

        def trim_results(results)
          return [] if results.blank?

          max_chars = 20_000
          used_chars = 0

          trimmed =
            results.each_with_object([]) do |entry, acc|
              file = entry[:file].to_s
              lines = entry[:lines].to_s
              content = entry[:content].to_s

              entry_length = file.length + lines.length + content.length
              remaining = max_chars - used_chars

              break acc if remaining <= 0

              if entry_length > remaining
                # Require space for file and line metadata.
                metadata_length = file.length + lines.length
                break acc if metadata_length >= remaining

                allowed_content_length = remaining - metadata_length
                content = content[0...allowed_content_length]
                entry_length = metadata_length + content.length
              end

              acc << entry.merge(content: content)
              used_chars += entry_length
            end

          trimmed
        end

        def format_line_label(line_range)
          return nil if line_range.nil?

          if line_range[:start_line] == line_range[:end_line]
            line_range[:start_line].to_s
          else
            "#{line_range[:start_line]}-#{line_range[:end_line]}"
          end
        end

        def fetch_file_content(repo_full_name, path, ref, cache, blob_sha)
          repo_full_name ||= repo

          cache_suffix = ref.presence || blob_sha.presence || "main"
          cache_key = "#{repo_full_name}@#{cache_suffix}:#{path}"
          return cache[cache_key] if cache.key?(cache_key)

          owner, repo_name = repo_full_name.to_s.split("/", 2)
          if owner.blank? || repo_name.blank?
            cache[cache_key] = nil
            return nil
          end

          url =
            if blob_sha.present?
              "https://api.github.com/repos/#{owner}/#{repo_name}/git/blobs/#{blob_sha}"
            else
              actual_ref = ref.presence || fetch_default_branch(repo_full_name)
              "https://api.github.com/repos/#{owner}/#{repo_name}/contents/#{path}?ref=#{actual_ref}"
            end

          response_code = nil
          body = nil

          send_http_request(
            url,
            headers: {
              "Accept" => "application/vnd.github.v3+json",
            },
            authenticate_github: true,
          ) do |response|
            response_code = response.code
            body = read_response_body(response)
          end

          if response_code == "200"
            begin
              data = JSON.parse(body)
              decoded = ensure_utf8(Base64.decode64(data["content"].to_s))
              cache[cache_key] = { content: decoded, total_lines: count_lines(decoded) }
            rescue JSON::ParserError
              cache[cache_key] = nil
            end
          else
            cache[cache_key] = nil
          end

          cache[cache_key]
        end

        def extract_ref(item)
          url = item["url"]
          return if url.blank?

          uri =
            begin
              URI.parse(url)
            rescue StandardError
              nil
            end
          return unless uri&.query

          CGI.parse(uri.query || "")["ref"]&.first
        end

        def derive_line_range(file_content, fragment)
          return if file_content.blank? || fragment.blank?

          file = normalize_line_endings(file_content)
          snippet = normalize_line_endings(fragment)

          # GitHub fragments mirror contiguous file sections, so match directly.
          index = file.index(snippet)
          return if index.nil?

          prefix = file[0...index]
          start_line = prefix.count("\n") + 1
          line_count = snippet.each_line.count

          { start_line: start_line, end_line: start_line + line_count - 1 }
        end

        def normalize_line_endings(text)
          text.gsub("\r\n", "\n")
        end

        def count_lines(content)
          return 0 if content.blank?

          normalized = normalize_line_endings(content)
          normalized.count("\n") + (normalized.end_with?("\n") ? 0 : 1)
        end

        def ensure_utf8(text)
          return "" if text.nil?

          result = text.dup
          result.force_encoding(Encoding::UTF_8)
          return result if result.valid_encoding?

          result.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
        end
      end
    end
  end
end
