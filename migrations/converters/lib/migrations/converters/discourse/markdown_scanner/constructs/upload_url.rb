# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Detects uploads referenced by a full URL instead of a short `upload://`
          # one — markdown images `![alt](url)`, markdown links `[text](url)` and
          # bare whitespace-delimited URLs. Three URL shapes are supported,
          # matching what core's file stores write (see core's `Upload` and
          # `FileStore`):
          #
          #   * a long URL: an `/uploads/` or `/secure-uploads/` segment with an
          #     `original/` or `optimized/` path below it, and a basename that
          #     starts with the upload's 40-hex sha1;
          #   * an S3/CDN URL: the same `original/` or `optimized/` path with no
          #     `/uploads/` segment, directly under the host or below a bucket
          #     prefix. Only with a host — no local store writes a relative
          #     `/original/…` path, so a relative one stays unrecognized;
          #   * a short-URL path: `/uploads/short-url/<token>[.ext]`, where the
          #     token is the base62-encoded sha1 (core's `Upload#short_path`).
          #     It is decoded here, so the row carries the same 40-hex sha1 as a
          #     long URL and resolves the same way at import.
          #
          # The storage shape must sit in the URL's path: every path segment
          # stops at `?` and `#`, so an upload path inside a query or fragment
          # (`/redirect?to=/uploads/…`) makes no upload URL — rewriting the
          # redirect would swap the author's link for the file it points at.
          # Any other `/uploads/` path (a WordPress `wp-content/uploads/…` URL,
          # some unrelated site's file) is not an upload reference: it matches
          # no shape and is left alone.
          #
          # The whole URL is taken, including its query and fragment. Both are
          # capped (1024 and 255 bytes) so a generated URL cannot make the
          # pattern scan without bounds. A URL beyond a cap matches no shape at
          # all and stays as written — replacing only a prefix of a URL would
          # leave its tail behind the placeholder.
          #
          # Recognition does no host allowlisting: a URL that has a supported
          # shape but points at some other site still resolves to nothing at
          # import and comes back verbatim (see `UploadUrlReference`), so
          # matching it is safe. Both relative and absolute (http/https and
          # protocol-relative) forms are recognized in image and link syntax. A
          # bare URL follows the same rule as an internal link: an absolute bare
          # URL is recognized in prose, a relative one only at a `](…)` link
          # target — a relative path bare in prose stays plain text once cooked,
          # so rewriting it would turn text into a link.
          class UploadUrl < Base
            TRIGGERS = ["!", "[", "h", "H", "/"].freeze

            # The sha1 is 160 bits; base62 needs at most 27 characters for that.
            MAX_SHORT_TOKEN_LENGTH = 27
            private_constant :MAX_SHORT_TOKEN_LENGTH

            # One path segment: a URL-body character (see
            # `Base::URL_TERMINATORS`) that is also none of `/`, `?` and `#`.
            SEGMENT = /[^\/?##{Base::URL_TERMINATORS}]{1,255}/
            private_constant :SEGMENT

            # The scheme and host. The scheme is case-insensitive because
            # linkify-it reads it that way, so core links `HTTPS://…` too.
            ORIGIN = %r{(?<origin>(?i:https?:)?//#{SEGMENT})}
            private_constant :ORIGIN

            UPLOADS = %r{(?:secure-)?uploads/}
            private_constant :UPLOADS

            STORAGE = %r{(?:original|optimized)/}
            private_constant :STORAGE

            # An optional query and fragment, taken whole or not at all. The
            # lookahead after each part requires that nothing of it is left
            # over except sentence punctuation at a URL boundary, so an
            # over-cap query fails the whole URL instead of matching up to a
            # mid-query cut. A bare `?` or `#` with nothing after it is part
            # of the URL too — a markdown destination like `(…21.png?)` keeps
            # it, and so does the engine. The final guard backs sentence
            # punctuation out of the end of the match, except when that end
            # is such a bare marker.
            QUERY_FRAGMENT =
              /
                (?:
                  \?
                  (?:
                    [^##{Base::URL_TERMINATORS}]{1,1024} (?= [.,;:!?]* (?: [##{Base::URL_TERMINATORS}] | \z ) )
                    | (?= [.,;:!?]* (?: [##{Base::URL_TERMINATORS}] | \z ) | \# )
                  )
                )?
                (?:
                  \#
                  (?:
                    [^#{Base::URL_TERMINATORS}]{1,255} (?= [.,;:!?]* (?: [#{Base::URL_TERMINATORS}] | \z ) )
                    | (?= [.,;:!?]* (?: [#{Base::URL_TERMINATORS}] | \z ) )
                  )
                )?
                (?: (?<! [.,;:!?] ) | (?<= [?\#] ) )
              /x
            private_constant :QUERY_FRAGMENT

            # From the storage marker down to the basename and whatever follows
            # it: partition segments, the sha1, the extension or `_WxH` suffix
            # ending on a word character (a sentence's `.` after a bare URL
            # stays out), then an optional query and fragment. The caps take a
            # signed CDN URL whole; beyond them the URL matches no shape at
            # all (see the class comment). The repeated groups are atomic with
            # a lookahead deciding where they stop, so a failing candidate is
            # scanned once and never backtracked into; the segment-count and
            # length caps bound a single candidate.
            STORAGE_TAIL =
              %r{
                #{STORAGE}
                (?> (?: (?! \h{40}[._] ) #{SEGMENT} / ){0,16} )   # depth/partition segments
                (?<sha1> \h{40} ) (?=[._])                        # sha1, then the extension or `_WxH` suffix
                [^/?##{Base::URL_TERMINATORS}]{0,255} \w
                #{QUERY_FRAGMENT}
              }x
            private_constant :STORAGE_TAIL

            # The long shape, from `/uploads/` down through the storage path.
            LONG_TAIL =
              %r{
                / #{UPLOADS}
                (?> (?: (?! #{STORAGE} ) #{SEGMENT} / ){0,16} )
                #{STORAGE_TAIL}
              }x
            private_constant :LONG_TAIL

            # The short-URL shape. The token is base62, the extension optional
            # (core routes both spellings). `(?![\w/-])` stops the match when
            # more path follows — core's short-URL route has exactly one
            # segment after `short-url/` — and a query or fragment may follow
            # the segment like on any URL.
            SHORT_TAIL =
              %r{
                /uploads/short-url/
                (?<short_token>[0-9a-zA-Z]{1,#{MAX_SHORT_TOKEN_LENGTH}})
                (?:\.\w{1,15})?
                (?![\w/-])
                #{QUERY_FRAGMENT}
              }x
            private_constant :SHORT_TAIL

            # The three shapes. The `/uploads/` segment may be absent only in
            # the schemed or protocol-relative form — that is the S3/CDN
            # shape, where the storage path sits directly under the host or
            # below a bucket prefix. A relative URL must carry `/uploads/`.
            URL =
              %r{
                (?<upload_url>
                    #{ORIGIN} (?> (?: / (?! #{UPLOADS} | #{STORAGE} ) #{SEGMENT} ){0,16} )
                      (?: #{LONG_TAIL} | / #{STORAGE_TAIL} )
                  | (?> (?: / (?! #{UPLOADS} ) #{SEGMENT} ){0,16} ) #{LONG_TAIL}
                  | #{ORIGIN}? (?> (?: / (?! #{UPLOADS} ) #{SEGMENT} ){0,16} ) #{SHORT_TAIL}
                )
              }x
            private_constant :URL

            # `\G` anchors each match at `pos` so scanning stays linear. Alt text
            # and link text are the one shared label grammar (see
            # `Base::LINK_TEXT`): they take the single level of balanced brackets
            # CommonMark allows, so `[see [1]](<upload url>)` is deferred, but no
            # nested link or image — the `[` of `[![…](…)](…)` never starts a match
            # at the outer bracket, and the inner image is deferred on its own at
            # the `!` trigger.
            IMAGE = /\G!\[#{Base::LINK_TEXT}\]\(#{Base::LINK_GAP}#{URL}#{Base::LINK_TAIL}/
            private_constant :IMAGE

            LINK = /\G\[#{Base::LINK_TEXT}\]\(#{Base::LINK_GAP}#{URL}#{Base::LINK_TAIL}/
            private_constant :LINK

            BARE = /\G#{URL}/
            private_constant :BARE

            # Mirrors core's `Base62::KEYS`. A drift spec decodes sample tokens
            # through core's `Upload.sha1_from_base62_encoded` and compares.
            BASE62_KEYS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            private_constant :BASE62_KEYS

            ANCHORED_URL = /\A#{URL}/
            private_constant :ANCHORED_URL

            # Whether `raw` can contain a supported upload URL at all. This is
            # the cheap presence check for the {TierGate}: every supported
            # shape carries one of these markers, and a body with only
            # unrelated `/uploads/` paths (WordPress and friends) does not
            # become a candidate. A storage marker alone is not enough — the
            # S3/CDN shape needs a host, and the long shape an `uploads/`
            # segment, so prose that merely mentions `original/` sends nothing
            # to the engine.
            def self.candidate?(raw)
              return true if raw.include?("uploads/short-url/")
              return false unless raw.include?("original/") || raw.include?("optimized/")

              raw.include?("//") || raw.include?("uploads/")
            end

            # Whether an engine href/src value has a supported upload shape.
            # The {EngineScanner} tracks upload values with this, so the filter
            # and the grammar that later anchors the construct cannot disagree.
            # The match must start at the value's first byte — a substring
            # match would track a URL that merely contains an upload path, the
            # redirect case again, one level up — and may leave only wordless
            # linkify junk uncovered ({Base.swallowed_tail?}).
            def self.tracked_value?(value)
              return false unless candidate?(value)

              match = ANCHORED_URL.match(value)
              return false if match.nil?

              swallowed_tail?(value.byteslice(match.byteoffset(0).last..))
            end

            # The 40-hex sha1 for a short-URL token, or nil when the token is
            # not a valid base62 sha1. Mirrors core's
            # `Upload.sha1_from_base62_encoded`.
            def self.sha1_from_short_token(token)
              value = 0
              token.each_char do |char|
                digit = BASE62_KEYS.index(char)
                return nil if digit.nil?

                value = value * 62 + digit
              end

              hex = value.to_s(16)
              hex.length > 40 ? nil : hex.rjust(40, "0")
            end

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                match_with(IMAGE, input, pos)
              when 0x5b # `[`
                match_with(LINK, input, pos)
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            private

            def detect_bare(input, pos)
              detect_bare_url(input, pos, BARE) { |match| build_match(pos, match) }
            end

            def match_with(pattern, input, pos)
              match = match_at(pattern, input, pos)
              match && build_match(pos, match)
            end

            def build_match(pos, match)
              sha1 = match[:sha1] || self.class.sha1_from_short_token(match[:short_token])
              return nil if sha1.nil?

              origin = match[:origin]
              host = origin && UrlOrigin.split(origin)&.first
              url = match[:upload_url]
              # The path part of the matched URL, for the ownership check
              # against a configured path prefix (see `UploadUrlReference`).
              rest = origin ? url.byteslice(origin.bytesize..) : url

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: UploadUrlReference.new(sha1:, host:, rest:),
              )
            end
          end
        end
      end
    end
  end
end
