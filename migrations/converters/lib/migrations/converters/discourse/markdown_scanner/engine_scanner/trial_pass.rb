# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The escalation for a body count certification refused: prove each
          # candidate occurrence individually by substitution. One occurrence's
          # bytes are replaced with an inert marker word and the body is
          # re-parsed; if exactly one instance of that construct disappears
          # from the parse — and nothing appears that isn't the marker's own
          # doing — the occurrence provably was that construct, at that
          # position. The proof is a token-multiset delta, so it needs no line
          # maps: bodies count certification cannot even index (CR line
          # endings) or cannot trust literally (entity spellings) are just as
          # eligible.
          #
          # An occurrence inside a code span, a link label, or any other
          # context the engine skips changes nothing when replaced — its delta
          # is empty and it stays unproven. Unproven constructs stay verbatim;
          # the body still gets its proven constructs extracted. The caller's
          # refusal tally then counts bodies that keep at least one unproven
          # construct — the conversion's must-resolve list.
          #
          # This costs one engine parse per candidate occurrence, bounded by
          # {MAX_TRIALS}, on the well-under-1% of engine-tier bodies whose
          # certification refuses — measured-rare, so clarity beats cleverness.
          class TrialPass
            include Locating

            # A runaway body (hundreds of occurrences of a tracked value)
            # keeps its tail unproven rather than buying hundreds of parses.
            MAX_TRIALS = 48

            # Elapsed ceiling across a body's trials. The parse count alone
            # does not bound work — one adversarial body can drive every parse
            # toward the context timeout — so the wall clock cuts in first and
            # the tail stays unproven. A normal trial parses in well under a
            # millisecond; only a body that is already pathological gets here.
            TRIAL_SECONDS_BUDGET = 10.0

            Candidate = Data.define(:kind, :key, :text, :occurrence)
            private_constant :Candidate

            def initialize(scanner, input, data, cause)
              @scanner = scanner
              @input = input
              @data = data
              @cause = cause
              @trials = 0
              @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              @limit_hit = nil
              build_line_index
            end

            def result
              base = construct_multiset(@data)
              expected = tracked_expected(base)
              marker = build_marker

              spans = {}
              proven = 0
              expected.each do |entry|
                candidates_for(entry).each do |candidate|
                  next unless prove(base, candidate, marker) == :proven
                  proven += 1 if place(candidate, spans)
                end
              end
              unproven_quotes = prove_quotes(base, marker, spans)

              ordered, dropped = without_overlaps(spans.values.sort_by(&:start_pos))
              proven -= dropped
              unproven = expected.sum { |entry| entry[:count] } - proven + unproven_quotes

              Result.new(
                output: ordered.empty? ? @input : splice(ordered),
                cause: unproven > 0 ? (@limit_hit || @cause) : nil,
              )
            end

            private

            # The parse reduced to what a substitution may change: every
            # construct value the scan reports, the inline-code span count, and
            # the block-token inventory. Line maps are deliberately absent —
            # they are what a CR body cannot provide.
            def construct_multiset(data)
              counts = Hash.new(0)

              data["blocks"].each do |block|
                block["mentions"].each { |content| counts[[:mention, content]] += 1 }
                block["hashtags"].each { |hashtag| counts[[:hashtag, hashtag["slug"]]] += 1 }
                block["links"].each { |link| counts[[:url, link["href"]]] += 1 }
                block["images"].each { |src| counts[[:url, src]] += 1 }
                block["emojis"].each { |name| counts[[:emoji, name]] += 1 }
                counts[:code] += block["code"]
              end
              data["blockTokens"].each do |token|
                counts[[:block, token["type"], token["tag"]]] += 1
              end

              counts
            end

            # The tracked construct instances the body is expected to yield —
            # the denominator for `unproven`. Quotes are handled separately:
            # a quote header may legitimately carry nothing to remap, so its
            # extraction is best-effort there like in the certification pass.
            def tracked_expected(base)
              base.filter_map do |key, count|
                next unless key.is_a?(Array)

                kind, value = key
                text =
                  case kind
                  when :mention
                    value if @scanner.mention_tracked?(value.delete_prefix("@"))
                  when :hashtag
                    # Trailing colons stay outside the construct, as in the
                    # certification pass; the multiset key keeps the engine's
                    # exact value so the trial delta still matches its token.
                    stripped = value.sub(/:+\z/, "")
                    "##{stripped}" if !stripped.empty? && @scanner.hashtag_tracked?(stripped)
                  when :emoji
                    ":#{value}:" if @scanner.emoji_tracked?(value)
                  when :url
                    value if @scanner.url_tracked?(value)
                  end
                next if text.nil?

                { kind:, key:, text:, count: }
              end
            end

            def candidates_for(entry)
              whole = 0...@input.bytesize
              readings = entry[:kind] == :url ? url_readings(entry[:text]) : [entry[:text]]

              seen = {}
              readings.flat_map do |reading|
                occurrence_kind = entry[:kind] == :url ? :url : entry[:kind]
                occurrence_offsets(occurrence_kind, reading, whole).filter_map do |occurrence|
                  next if seen[occurrence.offset]
                  seen[occurrence.offset] = true
                  Candidate.new(kind: entry[:kind], key: entry[:key], text: reading, occurrence:)
                end
              end
            end

            # The delta rule: replacing the occurrence must remove exactly one
            # instance of the target construct and may only add constructs the
            # marker itself spells (a link whose destination became the marker
            # word). Anything else — a block appearing or vanishing, a
            # previously suppressed construct surfacing, the code-span count
            # moving — fails the proof.
            #
            # The outcome distinguishes why: `:not_construct` (the delta was
            # empty — the occurrence provably is not a live construct here, so
            # skipping it is exact, not a failure), `:mismatch` (the delta was
            # wrong in some other way), and `:limit`/`:budget` when no trial
            # ran at all. The distinction is what lets a caller count real
            # unproven constructs without counting shielded look-alikes.
            def prove(base, candidate, marker)
              elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
              if elapsed > TRIAL_SECONDS_BUDGET
                @limit_hit = :trial_budget
                return :budget
              end
              if (@trials += 1) > MAX_TRIALS
                @limit_hit ||= :trial_limit
                return :limit
              end

              occurrence = candidate.occurrence
              trial_body =
                "#{@input.byteslice(0, occurrence.offset)}#{marker}" \
                  "#{@input.byteslice((occurrence.offset + occurrence.length)..)}"
              trial = construct_multiset(@scanner.engine.scan([{ id: nil, raw: trial_body }]).first)

              removed = diff(base, trial)
              added = diff(trial, base)
              return :not_construct if removed.empty? && added.empty?
              return :mismatch if removed != { candidate.key => 1 }

              added.each_key do |key|
                return :mismatch unless key.is_a?(Array) && key[1].to_s.include?(marker)
              end
              :proven
            end

            def diff(left, right)
              left.each_with_object({}) do |(key, count), result|
                difference = count - right.fetch(key, 0)
                result[key] = difference if difference > 0
              end
            end

            def place(candidate, spans)
              match =
                if candidate.kind == :url
                  anchor_match(candidate.occurrence) ||
                    bare_value_match(candidate.key[1], candidate.occurrence)
                else
                  probe_match(candidate.kind, candidate.text, candidate.occurrence.offset)
                end

              # Position proven but nothing can take the construct whole (an
              # escaped-bracket label, a form beyond the pattern caps): it
              # stays verbatim AND unproven — a stale reference the caller
              # must hear about, not a silent success.
              return false if match.nil?

              spans[[match.start_pos, match.end_pos]] ||= match
              true
            end

            # Quote openers: the target delta is one `blockquote` bbcode block
            # disappearing. The opener's span comes from the header grammar
            # itself. Returns how many openers stay unproven-but-remappable: a
            # header the grammar cannot take, a failed or budgeted trial. A
            # header that parses but carries no username has nothing to remap
            # and a trial proving "not a live construct" (a `[quote=` inside a
            # code fence) is an exact skip — neither counts.
            def prove_quotes(base, marker, spans)
              return 0 if base.fetch([:block, "bbcode_open", "blockquote"], 0) == 0

              unproven = 0
              pos = 0
              while (offset = @input.byteindex(/\[quote=/i, pos))
                pos = offset + 1
                match = @scanner.quote_detector.detect_block_opener(@input, offset)
                if match.nil?
                  unproven += 1 unless @scanner.quote_detector.parseable_opener?(@input, offset)
                  next
                end

                candidate =
                  Candidate.new(
                    kind: :quote,
                    key: [:block, "bbcode_open", "blockquote"],
                    text: nil,
                    occurrence:
                      Locating::Occurrence.new(
                        offset: match.start_pos,
                        length: match.end_pos - match.start_pos,
                      ),
                  )

                outcome = prove(base, candidate, marker)
                if outcome == :proven
                  spans[[match.start_pos, match.end_pos]] ||= match
                elsif outcome != :not_construct
                  unproven += 1
                end
              end

              unproven
            end

            # Distinct proven spans that overlap (two anchors claiming the same
            # bytes) cannot both be spliced; the later one stays verbatim and
            # is counted back as unproven so the body keeps its refusal cause.
            def without_overlaps(ordered)
              kept = []
              dropped = 0

              ordered.each do |match|
                if kept.empty? || match.start_pos >= kept.last.end_pos
                  kept << match
                else
                  dropped += 1
                end
              end

              [kept, dropped]
            end

            def build_marker
              counter = 0
              marker = "trialmark0"
              marker = "trialmark#{counter += 1}" while @input.include?(marker)
              marker
            end
          end
        end
      end
    end
  end
end
