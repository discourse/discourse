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

            def detect(input, pos, _byte)
              match = match_at(OPENING, input, pos)
              return nil unless match

              username, name, post_number, topic_id = parse_attribution(match[:attribution])
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: QuoteAttribution.new(username:, name:, post_number:, topic_id:),
              )
            end

            private

            # The id bound (see `Base::ID_PATTERN`): an overlong run names no real
            # record, so the part is ignored like any unrecognized one.
            POST_PART = /\Apost:(#{Base::ID_PATTERN})\z/
            private_constant :POST_PART

            TOPIC_PART = /\Atopic:(#{Base::ID_PATTERN})\z/
            private_constant :TOPIC_PART

            USERNAME_PART = /\Ausername:(.+)\z/
            private_constant :USERNAME_PART

            # Splits a Discourse attribution into username, display name, and the
            # source coordinates. `post:`/`topic:` are the source's own post number
            # and topic id; keep them as integers so the importer can look up the
            # quoted post by them.
            #
            # With an explicit `username:` part, that is the username and the leading
            # bare token is the display name (kept only when it differs). Without one,
            # the leading token IS the username: Discourse omits `username:` exactly
            # when the display name equals the username, so a lone token is not a
            # distinct name.
            def parse_attribution(string)
              explicit_username = name = nil
              post_number = topic_id = nil

              string
                .split(",")
                .map(&:strip)
                .each_with_index do |part, index|
                  case part
                  when POST_PART
                    post_number = Regexp.last_match(1).to_i
                  when TOPIC_PART
                    topic_id = Regexp.last_match(1).to_i
                  when USERNAME_PART
                    explicit_username = Regexp.last_match(1)
                  else
                    name = part if index.zero? && !part.empty?
                  end
                end

              if explicit_username
                display_name = name if name && name != explicit_username
                [explicit_username, display_name, post_number, topic_id]
              else
                [name, nil, post_number, topic_id]
              end
            end
          end
        end
      end
    end
  end
end
