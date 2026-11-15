# frozen_string_literal: true

module DiscourseWorkflows
  class NodeError < StandardError
    HTML_SANITIZE_CONFIG = {
      elements: %w[a br code em strong],
      attributes: {
        "a" => %w[href title],
      },
      protocols: {
        "a" => {
          "href" => ["http", "https", :relative],
        },
      },
    }.freeze

    attr_reader :html

    def initialize(message = nil, summary: nil, html: nil)
      super(message)
      @summary = summary
      @html = Sanitize.fragment(html.to_s, HTML_SANITIZE_CONFIG).presence if html
    end

    # The message without its item or line location, so per-item failures can be grouped.
    def summary
      @summary || message
    end
  end
end
