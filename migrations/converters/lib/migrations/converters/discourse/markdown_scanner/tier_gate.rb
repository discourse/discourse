# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Classifies a post body before any extraction runs, so each body gets
        # the cheapest treatment that is exact for it (measured on a real corpus:
        # roughly half of all posts leave through `:none`):
        #
        #   :none   - nothing extractable; the body is returned untouched.
        #   :prose  - candidates, but no context-sensitive syntax; the
        #             {ProseScanner} extracts with plain boundary-checked
        #             detector matches.
        #   :engine - candidates AND syntax that makes context matter (code,
        #             escapes, HTML, CR endings, link syntax, construct-capable
        #             entities); extraction must understand the full grammar.
        #
        # The gate is conservative by construction: every check that could send
        # a body to a cheaper tier errs toward the more capable one, so a wrong
        # guess costs time, never a wrong extraction.
        class TierGate
          # A body with none of these characters can't hold any built-in
          # construct — the same reasoning as the scanner's own skip check:
          # `@` (mention), `[` (quote/attachment/image), `#` (hashtag), the
          # `uploads/` segment of a full upload URL. Named character entities
          # get their own alternative: `&commat;bob` spells a construct while
          # containing none of the trigger characters (numeric forms all
          # contain `#`).
          BASE_PRESENCE = %r{[@\[#]|uploads/|&[a-zA-Z][a-zA-Z0-9]{1,31};}
          private_constant :BASE_PRESENCE

          # Any line that could open indented code, including inside blockquote
          # markers and with tabs mixed into the run ("` \t`" reaches column
          # four too). Wider than the real opening rule on purpose: matching a
          # line that core would not read as code only costs the engine trip.
          INDENTED_LINE = /^[> ]*(?: {4}|\t)/
          private_constant :INDENTED_LINE

          # `[code]`, `[code=ruby]`, `[code lang=ruby]` all open a code block.
          BBCODE_CODE = /\[code[\s=\]]/i
          private_constant :BBCODE_CODE

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
          # contain — the common typographic and HTML-escape names, so ordinary
          # pasted prose (`&amp;`, `&hellip;`) doesn't route to the engine. The
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

          # @param detectors [Array<Detectors::Base>] the same list the scanners
          #   run — the gate derives its checks from what is actually wired.
          #   {Detectors::LinkSpan} never produces an embed, so it plays no part
          #   in candidacy.
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
              when Detectors::LinkSpan
                # Shield only; produces no embeds.
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
          # @return [Symbol] `:none`, `:prose` or `:engine`
          def classify(raw)
            return :none unless raw.match?(@presence)

            # A construct-capable entity is a candidate the regex tiers cannot
            # even see, and context-sensitive for the same reason — so it is
            # both a candidate and a danger.
            entity = construct_capable_entity?(raw)
            return :engine if entity
            return :prose unless danger?(raw)

            real_candidates?(raw) ? :engine : :none
          end

          private

          def danger?(raw)
            raw.include?("`") || raw.include?("\\") || raw.include?("<") || raw.include?("\r") ||
              raw.include?("~~~") || raw.include?("](") || raw.include?("]:") ||
              raw.include?("][") || INDENTED_LINE.match?(raw) || BBCODE_CODE.match?(raw)
          end

          def real_candidates?(raw)
            @assume_candidates || unconditional_candidate?(raw) || probe_candidate?(raw)
          end

          def unconditional_candidate?(raw)
            raw.include?("[quote") || raw.include?("upload://") || raw.include?("uploads/") ||
              @unconditional_patterns.any? { |pattern| raw.match?(pattern) }
          end

          # Runs the name-gated detectors at each of their trigger positions —
          # the same matches the scanners would make, minus code shielding,
          # which only ever removes matches. First hit wins; a body with no hit
          # extracts nothing on any path.
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

          def construct_capable_entity?(raw)
            return false unless raw.include?("&")

            raw.scan(NUMERIC_ENTITY) do
              code = Regexp.last_match(1)
              return true if construct_codepoint?(code)
            end

            raw.scan(NAMED_ENTITY) do
              return true unless IRRELEVANT_NAMED_ENTITIES.include?(Regexp.last_match(1))
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
