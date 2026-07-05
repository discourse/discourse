# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects only the opening tag of a Discourse quote (`[quote="…"]`); the
          # body and `[/quote]` stay in place, and any embeds inside the body are
          # still scanned. Returns nil for an unattributed `[quote]`.
          class Quote < Base
            OPENING = /\G\[quote="(?<attribution>[^"\]]*)"\]/

            def detect(input, pos)
              return nil unless input[pos] == "["

              match = OPENING.match(input, pos)
              return nil unless match

              username, post = parse_attribution(match[:attribution])
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: QuoteAttribution.new(username:, post:),
              )
            end

            private

            # The username is the explicit `username:` value when present (Discourse
            # uses it when the display name differs), else the leading bare token.
            def parse_attribution(string)
              username = post = name = nil

              string
                .split(",")
                .map(&:strip)
                .each_with_index do |part, index|
                  case part
                  when /\Apost:(\d+)\z/
                    post = Regexp.last_match(1)
                  when /\Atopic:\d+\z/
                    next
                  when /\Ausername:(.+)\z/
                    username = Regexp.last_match(1)
                  else
                    name = part if index.zero? && !part.empty?
                  end
                end

              [username || name, post]
            end
          end
        end
      end
    end
  end
end
