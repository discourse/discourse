# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The escalation when count matching refused a body: confirm each
          # candidate occurrence on its own. One occurrence's bytes are replaced
          # with a marker word and the body is parsed again. When only instances
          # of that construct disappear from the parse — normally exactly one,
          # several for a reference definition that serves several links — and
          # nothing appears that the marker itself does not explain, then the
          # occurrence was that construct, at that position. The check compares
          # token multisets and needs no line maps, so bodies with CR line
          # endings or entity spellings can use it too.
          #
          # An occurrence the engine skips changes nothing when replaced: its
          # delta is empty and it stays unconfirmed, which leaves it unchanged
          # (see {MarkdownScanner}). The confirmed ones are still extracted.
          #
          # Each candidate occurrence costs one engine parse, limited by
          # {MAX_SUBSTITUTIONS}. Count matching refuses well under 1% of
          # engine-tier bodies, so this stays cheap.
          class SubstitutionPass
            # A body with hundreds of occurrences of a tracked value keeps its
            # tail unconfirmed instead of paying hundreds of parses. One check
            # costs about a millisecond; a corpus run needed fewer than ninety
            # for every body but a generated keyword report.
            MAX_SUBSTITUTIONS = 128

            # Default time limit across a body's substitution checks. The parse
            # count alone does not bound the work: one generated worst-case body
            # can push every parse toward the context timeout, so the wall clock
            # stops first. A scanner on its slow retry passes a larger budget,
            # because there a single legitimate parse can take longer than this
            # whole default.
            SUBSTITUTION_SECONDS_BUDGET = 10.0

            def initialize(
              scanner,
              input,
              data,
              locator,
              cause,
              seconds_budget: SUBSTITUTION_SECONDS_BUDGET
            )
              @scanner = scanner
              @input = input
              @data = data
              @locator = locator
              @cause = cause
              @seconds_budget = seconds_budget
              @substitutions = 0
              @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              @limit_hit = nil
              @unplaced_cause = nil
            end

            def result
              base = construct_multiset(@data)
              expected = tracked_expected(base)
              marker = build_marker

              # A body with CR line endings skips the count-matching pass, so
              # `EngineScanner::MAX_SCANNED_VALUES` is checked here too.
              url_values = expected.count { |entry| entry[:kind] == :url }
              if url_values > MAX_SCANNED_VALUES
                return Result.new(output: @input, cause: :url_volume)
              end
              if expected.size - url_values > MAX_SCANNED_VALUES
                return Result.new(output: @input, cause: :name_volume)
              end

              # Once the limit or the budget is hit the loops stop, and the tail
              # then counts as unconfirmed through the expected totals below.
              spans = {}
              confirmed = 0
              expected.each do |entry|
                break if @limit_hit
                occurrences_for(entry).each do |occurrence|
                  break if @limit_hit
                  outcome, covered = confirm(base, entry, occurrence, marker)
                  next unless outcome == :confirmed
                  confirmed += covered if place(entry, occurrence, spans)
                end
              end
              unconfirmed_quotes = confirm_quotes(base, marker, spans)

              ordered, dropped = without_overlaps(spans.values.sort_by(&:start_pos))
              confirmed -= dropped
              unconfirmed = expected.sum { |entry| entry[:count] } - confirmed + unconfirmed_quotes

              Result.new(
                output: ordered.empty? ? @input : @locator.splice(ordered),
                cause: unconfirmed > 0 ? (@limit_hit || @unplaced_cause || @cause) : nil,
              )
            end

            private

            # Every construct value, the inline-code span count, and the
            # block-token inventory. Line maps are left out on purpose; they are
            # what a CR body cannot provide.
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
                key = [:block, token["type"], token["tag"]]
                key.push(token["username"], token["post"], token["topic"]) if quote_key?(key)
                counts[key] += 1
              end

              counts
            end

            # The denominator for `unconfirmed`. Quotes are handled separately:
            # a quote header may carry nothing to remap, so its extraction is
            # best-effort.
            def tracked_expected(base)
              base.filter_map do |key, count|
                next unless key.is_a?(Array)

                kind, value = key
                # The multiset key keeps the engine's exact value so a
                # substitution delta still matches its token; the raw text to
                # look for is folded.
                text =
                  case kind
                  when :mention
                    FoldedText.fold(value) if @scanner.mention_tracked?(value.delete_prefix("@"))
                  when :hashtag
                    hashtag = @scanner.hashtag_text(value)
                    FoldedText.fold(hashtag) if hashtag
                  when :emoji
                    FoldedText.fold(":#{value}:") if @scanner.emoji_tracked?(value)
                  when :url
                    value if @scanner.url_tracked?(value)
                  end
                next if text.nil?

                { kind:, key:, text:, count: }
              end
            end

            def occurrences_for(entry)
              if entry[:kind] == :url
                @locator.url_spans(entry[:text], 0...@input.bytesize)
              else
                @locator.folded_occurrences(entry[:kind], entry[:text])
              end
            end

            # The delta rule: replacing the occurrence must remove only
            # instances of the target construct, and may only add constructs
            # that spell the marker word. Anything else fails the check: a block
            # appearing or vanishing, a suppressed construct showing up, the
            # code-span count changing. Normally exactly one instance must
            # disappear; a URL occurrence on a reference-definition line may
            # remove several, because one definition serves every
            # `[text][label]` link that uses its label.
            #
            # Returns `[outcome, covered]`; `covered` is how many of the
            # target's tokens the confirmed occurrence accounts for. The outcome
            # says why a check did not confirm: `:not_construct` (empty delta —
            # the occurrence is not a live construct here, so skipping it is
            # correct), `:mismatch`, `:limit`/`:budget` when no check ran. The
            # distinction lets the caller count real unconfirmed constructs
            # without counting shielded look-alikes.
            def confirm(base, entry, occurrence, marker)
              elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
              if elapsed > @seconds_budget
                @limit_hit = :substitution_budget
                return :budget, 0
              end
              if (@substitutions += 1) > MAX_SUBSTITUTIONS
                @limit_hit ||= :substitution_limit
                return :limit, 0
              end

              substituted_body =
                "#{@input.byteslice(0, occurrence.offset)}#{replacement_for(entry, marker)}" \
                  "#{@input.byteslice((occurrence.offset + occurrence.length)..)}"
              begin
                substituted =
                  construct_multiset(
                    @scanner.engine_scan([{ id: nil, raw: substituted_body }]).first,
                  )
              rescue EngineScanner::RetryDeadlineError
                @limit_hit = :substitution_budget
                return :budget, 0
              rescue MiniRacer::ScriptTerminatedError
                # On the slow retry the call's ceiling is the time left until
                # the per-body deadline, so a terminated check means the
                # deadline is spent, not that the engine failed.
                raise unless @scanner.retry_deadline_active?

                @scanner.reset_engine!
                @limit_hit = :substitution_budget
                return :budget, 0
              end

              removed = diff(base, substituted)
              added = diff(substituted, base)
              return :not_construct, 0 if removed.empty? && added.empty?

              if entry[:kind] == :quote
                # The marker keeps the quote a quote, so only its header fields
                # move; the body's own blocks stay where they are.
                unless removed.size == 1 && quote_key?(removed.keys.first) &&
                         removed.values.first == 1
                  return :mismatch, 0
                end
                covered = 1
              else
                return :mismatch, 0 if removed.keys != [entry[:key]]

                covered = removed[entry[:key]]
                if covered != 1
                  unless entry[:kind] == :url && definition_occurrence?(entry[:text], occurrence)
                    return :mismatch, 0
                  end
                end
              end

              added.each_key do |key|
                unless key.is_a?(Array) && key.any? { |part| part.to_s.include?(marker) }
                  return :mismatch, 0
                end
              end
              [:confirmed, covered]
            end

            def definition_occurrence?(text, occurrence)
              @locator.definition_offsets(text).include?([occurrence.offset, occurrence.length])
            end

            def diff(left, right)
              left.each_with_object({}) do |(key, count), result|
                difference = count - right.fetch(key, 0)
                result[key] = difference if difference > 0
              end
            end

            def place(entry, occurrence, spans)
              if entry[:kind] == :url
                match =
                  @locator.anchor_match(occurrence) ||
                    @locator.bare_value_match(entry[:key][1], occurrence)

                # The position is confirmed, but no grammar can take the
                # construct whole (an escaped-bracket label, a form beyond the
                # pattern caps). It stays unchanged AND counts as unconfirmed —
                # a stale reference the caller must hear about.
                if match.nil?
                  @unplaced_cause ||= @scanner.unplaced_url_cause(entry[:key][1])
                  return false
                end
              else
                match = @locator.node_match(entry[:kind], occurrence)
              end

              # Two readings of one URL, or a self-link's label and destination,
              # can both confirm the same match.
              key = [match.start_pos, match.end_pos]
              return false if spans.key?(key)

              spans[key] = match
              true
            end

            # Quote openers: the target delta is one `blockquote` bbcode block
            # disappearing. Returns how many openers stay unconfirmed but
            # remappable. Two cases do not count: a header that parses but has
            # no username (nothing to remap), and a check that answered "not a
            # live construct" (a `[quote=` inside a code fence).
            def confirm_quotes(base, marker, spans)
              return 0 if base.keys.none? { |key| quote_key?(key) }

              quote_entry = { kind: :quote, key: nil, text: nil }
              unconfirmed = 0
              pos = 0
              while (offset = @input.byteindex(/\[quote=/i, pos))
                # Once the limit or the budget is hit the body carries its
                # refusal anyway, so scanning the remaining openers would only
                # cost time.
                break if @limit_hit
                pos = offset + 1
                match = @scanner.quote_construct.detect_block_opener(@input, offset)
                if match.nil?
                  unconfirmed += 1 unless @scanner.quote_construct.parseable_opener?(@input, offset)
                  next
                end

                occurrence =
                  Locator::Occurrence.new(
                    offset: match.start_pos,
                    length: match.end_pos - match.start_pos,
                  )
                outcome, = confirm(base, quote_entry, occurrence, marker)
                if outcome == :confirmed
                  spans[[match.start_pos, match.end_pos]] ||= match
                elsif outcome != :not_construct
                  unconfirmed += 1
                end
              end

              unconfirmed
            end

            # The later one is counted back as unconfirmed, so the body keeps
            # its refusal cause.
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

            # The marker keeps the shape core dispatches on, or the marked parse
            # gains or loses tokens the occurrence never produced: an
            # `upload://` source keeps its scheme (core leaves an upload
            # image's alt alone but linkifies a URL in any other alt), a web
            # URL keeps its scheme, and a quote opener stays a quote opener.
            def replacement_for(entry, marker)
              return "[quote=\"#{marker}\"]" if entry[:kind] == :quote
              return marker unless entry[:kind] == :url

              value = entry[:key][1]
              if value.start_with?("upload://")
                "upload://#{marker}#{File.extname(value)}"
              elsif (scheme = value[%r{\A(https?)://}i, 1])
                # An autolink `<…>` stays an autolink only with a scheme; the
                # bare word alone on a line would parse as an HTML block.
                "#{scheme}://#{marker}"
              else
                marker
              end
            end

            def quote_key?(key)
              key.is_a?(Array) && key[0] == :block && key[1] == "bbcode_open" &&
                key[2] == "blockquote"
            end

            def build_marker
              counter = 0
              marker = "substmark0"
              marker = "substmark#{counter += 1}" while @input.include?(marker)
              marker
            end
          end
        end
      end
    end
  end
end
