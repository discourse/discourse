# frozen_string_literal: true

module WebsiteBrand
  # Fetches a page and the files it links to through FinalDestination, which
  # refuses private and internal addresses. Every file has a size limit, and
  # all requests share one time budget so a slow site can't hold a caller up.
  class Fetcher
    TIME_BUDGET = 20
    REQUEST_TIMEOUT = 5
    MIN_REQUEST_TIME = 1
    MAX_REDIRECTS = 3

    Response = Data.define(:body, :url)

    def initialize(time_budget: TIME_BUDGET)
      @deadline = now + time_budget
    end

    # Text over max_bytes is cut short, since the start of a page or a
    # stylesheet is still useful on its own.
    def text(url, max_bytes:, accept:)
      body, final_url, content_type, = fetch(url, max_bytes:, accept:)
      return if body.blank?

      Response.new(body: to_utf8(body.byteslice(0, max_bytes), content_type), url: final_url)
    end

    # Files over max_bytes are skipped, since part of an image is no use.
    def binary(url, max_bytes:)
      body, final_url, _, complete = fetch(url, max_bytes:, accept: "image/*")
      Response.new(body:, url: final_url) if complete && body.present?
    end

    private

    def fetch(url, max_bytes:, accept:)
      return if remaining < MIN_REQUEST_TIME

      body = +""
      content_type = nil
      complete = true
      destination =
        FinalDestination.new(
          url,
          timeout: [REQUEST_TIMEOUT, remaining].min,
          max_redirects: MAX_REDIRECTS,
          headers: {
            "Accept" => accept,
          },
        )

      final_url =
        destination.get do |response, chunk, _uri|
          next if chunk.nil?

          content_type ||= response["content-type"]
          body << chunk
          if body.bytesize > max_bytes || remaining <= 0
            complete = false
            throw :done
          end
        end

      [body, final_url, content_type, complete] if final_url
    rescue StandardError
      # an unreachable or misbehaving site only means fewer signals
      nil
    end

    def to_utf8(body, content_type)
      charset = Encodings.charset_from_content_type(content_type) || "utf-8"
      text = body.force_encoding(charset)
      if text.encoding != Encoding::UTF_8
        text = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
      end
      text.scrub("")
    end

    def remaining
      @deadline - now
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
