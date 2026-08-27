# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Classifies a post body before any extraction runs (measured on a real
        # corpus: well over half of all posts leave through `:none`):
        #
        #   :none   - nothing extractable; the body is returned untouched.
        #   :engine - at least one candidate construct; the {EngineScanner}
        #             extracts it against the real discourse-markdown-it parse.
        #
        # The gate is conservative by construction: every check errs toward
        # `:engine`, so a wrong guess costs an engine parse, never a wrong
        # extraction.
        class TierGate
          # A body with none of these characters can't hold any built-in
          # construct: `@` (mention), `[` (quote/attachment/image), `#`
          # (hashtag), the `uploads/` segment of a full upload URL. Named
          # character entities
          # get their own alternative: `&commat;bob` spells a construct while
          # containing none of the trigger characters (numeric forms all
          # contain `#`).
          BASE_PRESENCE = %r{[@\[#]|uploads/|&[a-zA-Z][a-zA-Z0-9]{1,31};}
          private_constant :BASE_PRESENCE

          # Numeric character references, decoded and tested below — `&#64;bob`
          # can spell a mention without a literal `@` anywhere in the body.
          NUMERIC_ENTITY = /&#(x\h{1,7}|\d{1,7});/i
          private_constant :NUMERIC_ENTITY

          NAMED_ENTITY = /&([a-zA-Z][a-zA-Z0-9]{1,31});/
          private_constant :NAMED_ENTITY

          # A character that could take part in a construct or its name once an
          # entity decodes to it: Unicode alphanumerics and marks (unicode
          # usernames), the name interior characters, the trigger characters,
          # and the URL characters a route needs.
          CONSTRUCT_CHAR = %r{[\p{Alnum}\p{M}_@#:./-]}
          private_constant :CONSTRUCT_CHAR

          # Named entities that provably decode to a character no construct can
          # contain — the common typographic and HTML-escape names, so an
          # ordinary pasted `&amp;` or `&hellip;` neither makes a candidate here
          # nor refuses count certification in the {EngineScanner}. The
          # decoder is markdown-it's, whose full name table ships only as an
          # encoded trie, so this is an explicit allowlist rather than a
          # derived one; a spec decodes each name through the real engine and
          # fails if one ever turns construct-capable. Anything not listed is
          # treated as construct-capable — unknown names cost time, not
          # correctness.
          IRRELEVANT_NAMED_ENTITIES = %w[
            amp
            AMP
            apos
            asymp
            bdquo
            bull
            cent
            copy
            curren
            dagger
            Dagger
            darr
            deg
            divide
            ensp
            emsp
            euro
            ge
            gt
            GT
            harr
            hellip
            infin
            laquo
            larr
            ldquo
            le
            lrm
            lsquo
            lt
            LT
            mdash
            middot
            nbsp
            ndash
            ne
            para
            plusmn
            pound
            prime
            Prime
            quot
            QUOT
            raquo
            rarr
            rdquo
            reg
            rlm
            rsquo
            sbquo
            sect
            shy
            thinsp
            times
            trade
            uarr
            yen
            zwj
            zwnj
          ].to_set.freeze

          # @param detectors [Array<Detectors::Base>] the same list the
          #   {EngineScanner} anchors with — the gate derives its checks from
          #   what is actually wired.
          def initialize(detectors:)
            @presence = Regexp.union(BASE_PRESENCE, *detectors.filter_map(&:presence_pattern))

            # The name-gated detectors answer "would anything actually be
            # extracted?" exactly — a probe just runs them at their triggers.
            # Every other detector extracts wherever its pattern matches, so its
            # presence alone makes a body worth scanning.
            probed = []
            @unconditional_patterns = []
            unknown = false

            detectors.each do |detector|
              case detector
              when Detectors::Mention, Detectors::Hashtag, Detectors::Emoji
                probed << detector
              when Detectors::Quote, Detectors::Upload, Detectors::UploadUrl
                # Covered by the fixed checks in `unconditional_candidate?`.
              when Detectors::InternalLink
                @unconditional_patterns << detector.presence_pattern
              else
                # A detector this gate doesn't know: classification can't rule
                # its constructs out, so candidacy is assumed whenever presence
                # hits.
                unknown = true
              end
            end

            @assume_candidates = unknown

            @probe_dispatch = {}
            probed.each do |detector|
              detector.triggers.each { |char| (@probe_dispatch[char.ord] ||= []) << detector }
            end
            @probe_dispatch.each_value(&:freeze)
            @probe_dispatch.freeze

            @probe_stop =
              if probed.empty?
                nil
              else
                chars = probed.flat_map(&:triggers).uniq
                Regexp.new("[#{chars.map { |char| Regexp.escape(char) }.join}]")
              end
          end

          # @param raw [String]
          # @return [Symbol] `:none` or `:engine`
          def classify(raw)
            return :none unless raw.match?(@presence)

            # A construct-capable entity is a candidate the byte checks cannot
            # see: `&#64;bob` spells a mention without a literal `@` anywhere.
            return :engine if construct_capable_entity?(raw)

            real_candidates?(raw) ? :engine : :none
          end

          # Whether `text` holds a character reference that can decode into a
          # construct-relevant character. Public because the engine tier's
          # count certification has the same blind spot as the presence check:
          # entities decode before the engine's text rules run, so a token's
          # value no longer has to exist as literal bytes.
          def construct_capable_entity?(text)
            return false unless text.include?("&")

            text.scan(NUMERIC_ENTITY) do
              code = Regexp.last_match(1)
              return true if construct_codepoint?(code)
            end

            text.scan(NAMED_ENTITY) do
              return true unless IRRELEVANT_NAMED_ENTITIES.include?(Regexp.last_match(1))
            end

            false
          end

          # The byte offsets of every construct-capable reference in `text`,
          # sorted — so the engine tier checks a region with a binary search
          # instead of slicing and rescanning it per region.
          def construct_capable_entity_offsets(text)
            return [] unless text.include?("&")

            offsets = []
            [
              [NUMERIC_ENTITY, ->(match) { construct_codepoint?(match[1]) }],
              [NAMED_ENTITY, ->(match) { !IRRELEVANT_NAMED_ENTITIES.include?(match[1]) }],
            ].each do |pattern, capable|
              pos = 0
              while (match = pattern.match(text, pos))
                offsets << match.byteoffset(0).first if capable.call(match)
                pos = match.end(0)
              end
            end
            offsets.sort!
            offsets
          end

          private

          def real_candidates?(raw)
            @assume_candidates || unconditional_candidate?(raw) || probe_candidate?(raw)
          end

          # `[quote=` is matched case-insensitively because core's bbcode tags
          # are (`[QUOTE=bob]` renders); the `=` is required because only a
          # metadata-bearing opener holds user/post/topic fields to remap — a
          # plain `[quote]` block extracts nothing on any path, and both the
          # certification and trial passes search openers with exactly this
          # shape. The `upload://` scheme is not case-insensitive, because
          # core's upload rewriting is case-sensitive there and an `UPLOAD://`
          # link carries nothing an importer could resolve.
          def unconditional_candidate?(raw)
            raw.match?(/\[quote=/i) || raw.include?("upload://") || raw.include?("uploads/") ||
              @unconditional_patterns.any? { |pattern| raw.match?(pattern) }
          end

          # Runs the name-gated detectors at each of their trigger positions —
          # a superset of what the engine can recognize there (code shielding
          # and link structure only ever remove matches). First hit wins; a
          # body with no hit extracts nothing on any path.
          def probe_candidate?(raw)
            return false unless @probe_stop

            pos = 0
            while (index = raw.byteindex(@probe_stop, pos))
              byte = raw.getbyte(index)
              @probe_dispatch[byte]&.each do |detector|
                return true if detector.detect(raw, index, byte)
              end
              pos = index + 1
            end
            false
          end

          def construct_codepoint?(code)
            codepoint = code.start_with?("x", "X") ? code[1..].to_i(16) : code.to_i
            return false if codepoint == 0 || codepoint > 0x10ffff
            return false if codepoint >= 0xd800 && codepoint <= 0xdfff

            CONSTRUCT_CHAR.match?(codepoint.chr(Encoding::UTF_8))
          end
        end
      end
    end
  end
end
