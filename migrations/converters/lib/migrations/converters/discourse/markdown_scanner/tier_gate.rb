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
        #             extracts it against the real parse.
        #
        # Every check errs toward `:engine`, so a wrong guess costs an engine
        # parse, never a wrong extraction.
        class TierGate
          # A body with none of these characters cannot hold any built-in
          # construct: `@` (mention), `[` (quote/attachment/image), `#`
          # (hashtag), the `uploads/` segment of a full upload URL or the
          # `original/`/`optimized/` storage segment of an S3/CDN one. Named
          # character entities get their own alternative because `&commat;bob`
          # spells a construct while containing none of the trigger characters;
          # numeric forms all contain `#`.
          BASE_PRESENCE = %r{[@\[#]|uploads/|(?:original|optimized)/|&[a-zA-Z][a-zA-Z0-9]{1,31};}
          private_constant :BASE_PRESENCE

          # Numeric character references, decoded and tested below: `&#64;bob`
          # can spell a mention with no literal `@` in the body.
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

          # Named entities that decode to a character no construct can contain,
          # so that an ordinary pasted `&amp;` or `&hellip;` makes no candidate
          # here. markdown-it ships its full name table only as an encoded trie,
          # hence this explicit allowlist; a spec decodes each name through the
          # real engine and fails if one can form a construct character.
          # Anything not listed counts as construct-capable — an unknown name
          # costs time, not correctness.
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

          # A name-gated construct's probe: which bytes open it, the folded
          # names it accepts, and the byte that has to close the name (only the
          # emoji shortcode has one).
          Probe =
            Data.define(:names, :triggers, :terminator) do
              def initialize(names:, triggers:, terminator: nil)
                super
              end
            end
          private_constant :Probe

          # How many raw bytes a name of N folded bytes may span. Folding maps
          # each grapheme cluster on its own and can shrink one — a decomposed
          # cluster composing into a single character, `K` (U+212A) downcasing
          # to `k` — so a raw spelling can be longer than the name it folds to.
          NAME_WINDOW_FACTOR = 4
          private_constant :NAME_WINDOW_FACTOR

          # @param constructs [Array<Constructs::Base>] the same list the
          #   {EngineScanner} anchors with, so the gate follows what is wired.
          def initialize(constructs:)
            @presence = Regexp.union(BASE_PRESENCE, *constructs.filter_map(&:presence_pattern))

            # The name-gated constructs answer "could anything be extracted?" by
            # name: a probe folds the bytes after each trigger and asks their
            # name sets. Every other construct extracts wherever its pattern
            # matches, so presence alone makes a body worth scanning.
            probed = []
            @unconditional_patterns = []
            unknown = false

            constructs.each do |construct|
              case construct
              when Constructs::Mention, Constructs::Hashtag
                probed << Probe.new(names: construct.names, triggers: construct.triggers)
              when Constructs::Emoji
                # Requiring the closing `:` keeps every colon a tracked name
                # happens to follow from becoming a candidate — a colon is far
                # more common in prose than `@` or `#`.
                probed << Probe.new(
                  names: construct.names,
                  triggers: construct.triggers,
                  terminator: ":".ord,
                )
              when Constructs::Quote, Constructs::Upload, Constructs::UploadUrl
                # Covered by the fixed checks in `unconditional_candidate?`.
              when Constructs::InternalLink
                @unconditional_patterns << construct.presence_pattern
              else
                # An unknown construct cannot be ruled out, so candidacy is
                # assumed whenever presence hits.
                unknown = true
              end
            end

            @assume_candidates = unknown

            @probe_dispatch = {}
            probed.each do |probe|
              probe.triggers.each { |char| (@probe_dispatch[char.ord] ||= []) << probe }
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

            # A construct-capable entity is a candidate no byte check can see.
            return :engine if TierGate.construct_capable_entity?(raw)

            real_candidates?(raw) ? :engine : :none
          end

          # Whether `text` holds a character reference that can decode into a
          # construct-relevant character. The gate and the engine tier share
          # this blind spot, so both read it here.
          def self.construct_capable_entity?(text)
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
          # sorted, so the engine tier checks a region with a binary search
          # instead of slicing and rescanning it per region.
          def self.construct_capable_entity_offsets(text)
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

          # The `=` after `[quote` is required: only an opener with metadata
          # holds user/post/topic fields to remap, and both passes search
          # openers with exactly this shape. The `upload://` scheme stays
          # case-sensitive because core's upload rewriting is; an `UPLOAD://`
          # link carries nothing an importer could resolve. Full upload URLs go
          # through the construct's own check, so an unrelated `/uploads/` path
          # makes no candidate.
          def unconditional_candidate?(raw)
            raw.match?(/\[quote=/i) || raw.include?("upload://") ||
              Constructs::UploadUrl.candidate?(raw) ||
              @unconditional_patterns.any? { |pattern| raw.match?(pattern) }
          end

          # Asks at each trigger position whether the bytes after it could spell
          # a tracked name — a superset of what the engine can recognize there,
          # with no boundary or name grammar, so `\@bob` (which core cooks) is a
          # candidate like `@bob` is. Over-approximating costs an engine parse;
          # ruling out wrongly costs a construct.
          def probe_candidate?(raw)
            return false unless @probe_stop

            pos = 0
            while (index = raw.byteindex(@probe_stop, pos))
              @probe_dispatch[raw.getbyte(index)]&.each do |probe|
                return true if tracked_prefix?(raw, index + 1, probe)
              end
              pos = index + 1
            end
            false
          end

          # Whether some prefix of the text after a trigger folds to one of the
          # construct's names. An ASCII window folds by downcasing it whole; a
          # multibyte one grows its prefixes by grapheme cluster, as
          # {FoldedText} defines folding.
          def tracked_prefix?(raw, from, probe)
            max_bytes = probe.names.max_byte_length
            return false if max_bytes == 0

            window = probe_window(raw, from, max_bytes)
            return false if window.empty?

            if window.ascii_only?
              ascii_tracked_prefix?(raw, from, probe, window.downcase, max_bytes)
            else
              folded_tracked_prefix?(raw, from, probe, window, max_bytes)
            end
          end

          def ascii_tracked_prefix?(raw, from, probe, folded, max_bytes)
            length = 0
            limit = [max_bytes, folded.bytesize].min
            while (length += 1) <= limit
              next unless probe.names.include?(folded.byteslice(0, length))
              return true if probe.terminator.nil? || raw.getbyte(from + length) == probe.terminator
            end
            false
          end

          def folded_tracked_prefix?(raw, from, probe, window, max_bytes)
            folded = +""
            offset = from
            window.each_grapheme_cluster do |cluster|
              folded << FoldedText.fold(cluster)
              offset += cluster.bytesize
              break if folded.bytesize > max_bytes
              next unless probe.names.include?(folded)
              return true if probe.terminator.nil? || raw.getbyte(offset) == probe.terminator
            end
            false
          end

          # The bytes a name may reach over: never across whitespace, since no
          # value the engine reports for these constructs holds any, and never
          # more than {NAME_WINDOW_FACTOR} times the longest name.
          def probe_window(raw, from, max_bytes)
            limit = [from + max_bytes * NAME_WINDOW_FACTOR, raw.bytesize].min
            stop = from
            while stop < limit
              byte = raw.getbyte(stop)
              break if byte == 0x20 || (byte >= 0x09 && byte <= 0x0d)
              stop += 1
            end
            # A window cut at the byte limit must not cut a character in half.
            stop += 1 while stop < raw.bytesize && (raw.getbyte(stop) & 0xC0) == 0x80
            raw.byteslice(from, stop - from)
          end

          def self.construct_codepoint?(code)
            codepoint = code.start_with?("x", "X") ? code[1..].to_i(16) : code.to_i
            return false if codepoint == 0 || codepoint > 0x10ffff
            return false if codepoint >= 0xd800 && codepoint <= 0xdfff

            CONSTRUCT_CHAR.match?(codepoint.chr(Encoding::UTF_8))
          end
          private_class_method :construct_codepoint?
        end
      end
    end
  end
end
