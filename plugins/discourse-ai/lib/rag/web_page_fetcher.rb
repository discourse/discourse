# frozen_string_literal: true

module DiscourseAi
  module Rag
    class WebPageFetcher
      MAX_RESPONSE_BODY_LENGTH = 5.megabytes
      MAX_REDIRECTS = 5
      ACCEPT_HEADER = "text/markdown, */*"
      SUPPORTED_CONTENT_TYPES = %w[text/html application/xhtml+xml text/plain text/markdown].freeze

      FetchError = Class.new(StandardError)

      class << self
        def fetch(url:, etag: nil, last_modified: nil)
          new(url:, etag:, last_modified:).fetch
        end
      end

      def initialize(url:, etag:, last_modified:)
        @url = url
        @etag = etag
        @last_modified = last_modified
      end

      def fetch
        uri = parse_uri(@url)

        (MAX_REDIRECTS + 1).times do |redirect_count|
          response = request(uri)
          return build_result(response, uri) if response[:location].blank?
          raise FetchError, "The page redirected too many times" if redirect_count == MAX_REDIRECTS

          uri = parse_uri(URI.join(uri.to_s, response[:location]).to_s)
        end
      rescue FetchError
        raise
      rescue FinalDestination::SSRFError,
             SocketError,
             Timeout::Error,
             OpenSSL::SSL::SSLError,
             EOFError,
             SystemCallError,
             URI::Error => error
        raise FetchError, error.message
      end

      private

      def request_headers
        { "Accept" => ACCEPT_HEADER }.tap do |headers|
          headers["If-None-Match"] = @etag if @etag.present?
          headers["If-Modified-Since"] = @last_modified if @last_modified.present?
        end
      end

      def parse_uri(url)
        uri = URI.parse(UrlHelper.normalized_encode(url))
        if !uri.scheme.in?(%w[http https]) || uri.host.blank? || uri.userinfo.present?
          raise FetchError, "The page URL is invalid"
        end

        uri
      end

      def request(uri)
        result = nil
        request = FinalDestination::HTTP::Get.new(uri.request_uri, request_headers)
        request["User-Agent"] = DiscourseAi::AiBot::USER_AGENT

        FinalDestination::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: FinalDestination.connection_timeout,
        ) do |http|
          http.read_timeout = FinalDestination.connection_timeout
          http.request(request) do |response|
            if response.code == "304"
              result = { code: response.code }
            elsif Net::HTTPRedirection === response
              result = { code: response.code, location: response["Location"] }
            elsif response.code != "200"
              result = { code: response.code }
            else
              result = {
                code: response.code,
                content_type: response["Content-Type"],
                etag: response["ETag"],
                last_modified: response["Last-Modified"],
                body: read_body(response),
              }
            end
          end
        end

        result || raise(FetchError, "The page could not be fetched")
      end

      def read_body(response)
        body = +""
        response.read_body do |chunk|
          body << chunk
          if body.bytesize > MAX_RESPONSE_BODY_LENGTH
            raise FetchError, "The page is larger than 5 MB"
          end
        end
        body.scrub
      end

      def build_result(response, resolved_uri)
        return { not_modified: true } if response[:code] == "304"

        raise FetchError, "The page returned HTTP #{response[:code]}" if response[:code] != "200"

        content_type = response[:content_type].to_s.split(";", 2).first.downcase
        if content_type.present? && SUPPORTED_CONTENT_TYPES.exclude?(content_type)
          raise FetchError, "Unsupported content type: #{content_type}"
        end

        body = response[:body]
        text = content_type.in?(%w[text/plain text/markdown]) ? body : extract_html(body)
        raise FetchError, "The page did not contain readable text" if text.blank?

        {
          not_modified: false,
          url: resolved_uri.to_s,
          text: text,
          etag: response[:etag],
          last_modified: response[:last_modified],
        }
      end

      def extract_html(html)
        document = Nokogiri.HTML5(html)
        document.search("script, style, noscript, template").remove

        main_content =
          document.at("article") || document.at("main") || document.at("[role='main']") ||
            document.at("#main") || document.at(".main") || document.at("#content") ||
            document.at(".content") || document.at("body")

        text_content(main_content)
      end

      def text_content(node)
        return "" if node.blank?

        segments =
          node
            .xpath(".//text()[not(ancestor::table)] | .//table[not(ancestor::table)]")
            .filter_map do |child|
              if child.name == "table"
                table_text = table_to_markdown(child) || normalize_whitespace(child.text)
                "\n\n#{table_text}\n\n" if table_text.present?
              else
                normalize_whitespace(child.text) if child.text.present?
              end
            end

        segments.join(" ").gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
      end

      def table_to_markdown(table)
        rows = table.xpath("./tr | ./thead/tr | ./tbody/tr | ./tfoot/tr")
        cells_by_row = rows.map { |row| row.xpath("./th | ./td") }
        column_count = cells_by_row.map(&:length).max.to_i
        return if column_count < 2

        cells_by_row.select! do |cells|
          cells.length == column_count && cells.all? { |cell| cell_span(cell) == [1, 1] }
        end
        return if cells_by_row.length < 2

        lines =
          cells_by_row.map do |cells|
            "| #{cells.map { |cell| table_cell_text(cell) }.join(" | ")} |"
          end
        lines.insert(1, "| #{Array.new(column_count, "---").join(" | ")} |")
        lines.join("\n")
      end

      def table_cell_text(cell)
        text = cell.xpath(".//text()[not(ancestor::table[ancestor::table])]").map(&:text)
        labels =
          cell
            .xpath(".//*[@aria-label] | self::*[@aria-label]")
            .filter_map { |element| element["aria-label"] if element.text.blank? }

        normalize_whitespace((text + labels.uniq).join(" ")).gsub("|", "\\|")
      end

      def cell_span(cell)
        [cell["rowspan"].presence&.to_i || 1, cell["colspan"].presence&.to_i || 1]
      end

      def normalize_whitespace(text)
        text.to_s.gsub(/\s+/, " ").strip
      end
    end
  end
end
