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
            TRIGGERS = ["["].freeze

            OPENING = /\G\[quote="(?<attribution>[^"\]]*)"\]/

            def detect(input, pos, _char)
              match = OPENING.match(input, pos)
              return nil unless match

              username, post_number, topic_id = parse_attribution(match[:attribution])
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: QuoteAttribution.new(username:, post_number:, topic_id:),
              )
            end

            private

            # The username is the explicit `username:` value when present (Discourse
            # uses it when the display name differs), else the leading bare token.
            # `post:`/`topic:` are the source's own post number and topic id; keep
            # them as integers so the importer can look up the quoted post by them.
            def parse_attribution(string)
              username = name = nil
              post_number = topic_id = nil

              string
                .split(",")
                .map(&:strip)
                .each_with_index do |part, index|
                  case part
                  # At most 18 digits — a longer run overflows the signed 64-bit
                  # integer SQLite stores ids in, and names no real record. The
                  # attribution part is then ignored, like any unrecognized part.
                  when /\Apost:(\d{1,18})\z/
                    post_number = Regexp.last_match(1).to_i
                  when /\Atopic:(\d{1,18})\z/
                    topic_id = Regexp.last_match(1).to_i
                  when /\Ausername:(.+)\z/
                    username = Regexp.last_match(1)
                  else
                    name = part if index.zero? && !part.empty?
                  end
                end

              [username || name, post_number, topic_id]
            end
          end
        end
      end
    end
  end
end
