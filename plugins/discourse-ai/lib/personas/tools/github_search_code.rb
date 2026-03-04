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
              {
                name: "ignore_paths",
                description:
                  "File path prefixes to exclude from results (e.g., ['config/locales/', 'spec/'])",
                type: "array",
                item_type: "string",
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

        def ignore_paths
          Array(parameters[:ignore_paths]).map(&:to_s)
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
            formatted_results = format_results(search_data["items"])
            grouped = group_by_file(formatted_results)
            trimmed = trim_results(grouped)

            total_count = search_data["total_count"].to_i
            total_pages =
              if total_count <= 0
                1
              else
                [((total_count.to_f / PER_PAGE).ceil), MAX_ALLOWED_PAGE].min
              end

            result = { search_results: trimmed }

            result[:page] = page if page > 1
            result[:total_results] = total_count
            result[:next_page] = page + 1 if page < total_pages

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

        # Cap blob fetches to avoid excessive API calls for line-number enrichment.
        # Files beyond this limit still appear in results but without line numbers.
        MAX_BLOB_FETCHES = 10

        def format_results(items)
          return [] if items.blank?

          file_cache = {}
          blob_fetches = 0
          ignored = ignore_paths

          results =
            items.flat_map do |item|
              text_matches = item["text_matches"]
              next [] if text_matches.blank?

              path = item["path"]
              next [] if ignored.any? { |prefix| path.start_with?(prefix) }

              repo_full_name = item.dig("repository", "full_name") || repo
              ref =
                extract_ref(item) || item.dig("repository", "default_branch") ||
                  fetch_default_branch(repo_full_name)
              sha = item["sha"]

              cache_key = blob_cache_key(repo_full_name, path, ref, sha)
              if file_cache.key?(cache_key)
                file_details = file_cache[cache_key]
              elsif blob_fetches < MAX_BLOB_FETCHES
                file_details = fetch_file_content(repo_full_name, path, ref, file_cache, sha)
                blob_fetches += 1
              else
                file_details = nil
              end

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

        def group_by_file(results)
          return [] if results.blank?

          grouped = {}

          results.each do |entry|
            file = entry[:file]
            grouped[file] ||= { file: file, total_lines: entry[:total_file_lines], matches: [] }
            grouped[file][:matches] << { lines: entry[:lines], content: entry[:content] }
          end

          grouped.values
        end

        def trim_results(grouped_results)
          return [] if grouped_results.blank?

          max_chars = 20_000
          used_chars = 0

          grouped_results.each_with_object([]) do |file_entry, acc|
            file = file_entry[:file].to_s
            file_overhead = file.length + file_entry[:total_lines].to_s.length
            remaining = max_chars - used_chars

            break acc if remaining <= file_overhead

            trimmed_matches = []
            match_chars = 0

            file_entry[:matches].each do |match|
              lines = match[:lines].to_s
              content = match[:content].to_s
              entry_length = lines.length + content.length
              match_remaining = remaining - file_overhead - match_chars

              break if match_remaining <= 0

              if entry_length > match_remaining
                allowed = match_remaining - lines.length
                break if allowed <= 0
                content = content[0...allowed]
                entry_length = lines.length + content.length
              end

              trimmed_matches << { lines: match[:lines], content: content }
              match_chars += entry_length
            end

            next if trimmed_matches.empty?

            acc << {
              file: file_entry[:file],
              total_lines: file_entry[:total_lines],
              matches: trimmed_matches,
            }
            used_chars += file_overhead + match_chars
          end
        end

        def format_line_label(line_range)
          return nil if line_range.nil?

          if line_range[:start_line] == line_range[:end_line]
            line_range[:start_line].to_s
          else
            "#{line_range[:start_line]}-#{line_range[:end_line]}"
          end
        end

        def blob_cache_key(repo_full_name, path, ref, blob_sha)
          suffix = ref.presence || blob_sha.presence || "main"
          "#{repo_full_name || repo}@#{suffix}:#{path}"
        end

        def fetch_file_content(repo_full_name, path, ref, cache, blob_sha)
          repo_full_name ||= repo

          cache_key = blob_cache_key(repo_full_name, path, ref, blob_sha)
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
