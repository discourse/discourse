# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The per-body count-matching pass; the scanner itself stays
          # reusable across bodies.
          #
          # The pass answers one question: does the number of deduplicated raw
          # occurrences equal the number of engine tokens, exactly. Any
          # inequality escalates to the substitution pass, and so does any
          # value where the two numbers can legitimately differ (a reference
          # definition serving several links). The pass never accepts on
          # unequal counts and never decides from the shape of the bytes —
          # deciding what bytes mean is the engine's job, and the substitution
          # pass is the only place that asks it about a single occurrence.
          class CountingPass
            include Locating

            def initialize(scanner, input, data)
              @scanner = scanner
              @input = input
              @data = data
              build_line_index
            end

            def result
              spans = {}

              cause = collect_expected
              cause ||= match_all_counts
              cause ||= resolve_urls(spans)
              cause ||= resolve_probed(spans)
              cause ||= resolve_quotes(spans)
              return refusal(cause) if cause

              ordered = spans.values.sort_by(&:start_pos)
              return refusal(:overlap) if overlapping?(ordered)

              Result.new(output: ordered.empty? ? @input : splice(ordered), cause: nil)
            end

            private

            def refusal(cause)
              Result.new(output: @input, cause:)
            end

            def region_range(map)
              return nil if map.nil?

              from = @line_starts[map[0]]
              return nil if from.nil?

              to = @line_starts[map[1]] || @input.bytesize
              from...to
            end

            # Groups the engine's construct values: per (kind, value) the
            # expected count in each block region and in total. Values the
            # migration does not remap (external links, unknown names,
            # standard emoji) never enter count matching.
            def collect_expected
              @expected = {}
              regions_with_constructs = []

              @data["blocks"].each do |block|
                # Not every inline block has a line map; table cells do not.
                # A mapless block's constructs are counted against the whole
                # body, and the entity check widens accordingly.
                range = region_range(block["map"]) || (0...@input.bytesize)

                had = false
                block["mentions"].each do |content|
                  next unless @scanner.mention_tracked?(content.delete_prefix("@"))
                  had = true
                  add_expected(:mention, content, range, 1)
                end
                block["hashtags"].each do |hashtag|
                  text = @scanner.hashtag_text(hashtag["slug"])
                  next if text.nil?
                  had = true
                  add_expected(:hashtag, text, range, 1)
                end
                block["emojis"].each do |name|
                  next unless @scanner.emoji_tracked?(name)
                  had = true
                  add_expected(:emoji, ":#{name}:", range, 1)
                end
                block["links"].each do |link|
                  href = link["href"]
                  next unless @scanner.url_tracked?(href)
                  had = true
                  add_expected(:url, href, range, 1 + link["labelHits"])
                end
                block["images"].each do |src|
                  next unless @scanner.url_tracked?(src)
                  had = true
                  add_expected(:url, src, range, 1)
                end

                regions_with_constructs << range if had
              end

              url_values = @expected.count { |(kind, _), _| kind == :url }
              return :url_volume if url_values > MAX_URL_VALUES

              # Entities decode before the engine's text rules run, so a
              # token value may not exist as literal bytes in the raw text.
              # Counting cannot see through that.
              regions_with_constructs.uniq.each { |range| return :entity if entity_in?(range) }

              nil
            end

            def add_expected(kind, value, range, count)
              entry = @expected[[kind, value]] ||= { regions: Hash.new(0), total: 0 }
              entry[:regions][range] += count
              entry[:total] += count
            end

            # Two-stage count matching per value. A value matched inside its regions
            # replaces only those occurrences; the same value inside
            # a code fence elsewhere stays untouched. A value matched against the whole
            # body replaces every occurrence, and the entity check widens to
            # the whole body.
            #
            # A value with a reference-definition line never matches by
            # counting. One definition can serve several `[text][label]`
            # links, so the token count no longer says how many raw
            # occurrences are live — an equality can hold while one of the
            # counted occurrences is a copy inside a code fence. Only the
            # substitution pass can tell those apart.
            def match_all_counts
              whole = 0...@input.bytesize
              @matched = {}

              @expected.each do |(kind, value), entry|
                return :count_mismatch if kind == :url && definition_offsets(value).any?

                occurrences = match_region_counts(kind, value, entry)

                if occurrences
                  @matched[[kind, value]] = occurrences
                  next
                end

                return :entity if entity_offsets.any?

                global = match_counts_in(kind, value, whole, entry[:total])
                return :count_mismatch if global.nil?

                @matched[[kind, value]] = global
              end

              nil
            end

            # All regions matched and concatenated; nil when any region's
            # count does not match.
            def match_region_counts(kind, value, entry)
              occurrences = []
              entry[:regions].each do |range, expected|
                in_region = match_counts_in(kind, value, range, expected)
                return nil if in_region.nil?

                occurrences.concat(in_region)
              end
              occurrences
            end

            # The occurrences of a value in a range, when their number equals
            # what the engine saw; nil otherwise.
            def match_counts_in(kind, value, range, expected)
              if kind == :url
                spans, overlapping = url_spans(value, range)
                return nil if overlapping
              else
                spans = occurrences_within(probed_occurrences(kind, value), range)
              end

              spans if spans.size == expected
            end

            # Turns matched URL occurrences into node matches that cover the
            # whole construct. A destination inside `[text](…)` must be
            # replaced together with its syntax, so the classes match from the `[`
            # or `!` anchor; that also covers both occurrences of a
            # `[URL](same URL)` self-link with one node. An occurrence that
            # is its own syntax (a bare schemeless domain, a reference
            # definition's destination) resolves through the engine's href.
            # One that neither can take refuses the body; the substitution pass then
            # extracts what it can and the rest is reported.
            def resolve_urls(spans)
              @matched.each do |(kind, value), occurrences|
                next unless kind == :url

                occurrences.each do |occurrence|
                  match = anchor_match(occurrence) || bare_value_match(value, occurrence)
                  return @scanner.unplaced_url_cause(value) if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Mentions, hashtags and emoji: their matched occurrences came
            # from the constructs, so probing again returns the node directly.
            def resolve_probed(spans)
              @matched.each do |(kind, _value), occurrences|
                next if kind == :url

                occurrences.each do |occurrence|
                  match = probe_match_at(kind, occurrence)
                  # The index was built from construct matches; a miss here
                  # means the pass is inconsistent with itself.
                  return :probe_desync if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Quote openers come from block tokens: the engine reports the
            # quote's line range directly, so no counting is needed. The
            # header on the opening line is parsed in place. This includes
            # the single-line `[quote=…]body[/quote]` form.
            def resolve_quotes(spans)
              @data["blockTokens"].each do |token|
                next unless token["type"] == "bbcode_open" && token["tag"] == "blockquote"

                range = region_range(token["map"])
                next if range.nil?

                line_end = @line_starts[token["map"][0] + 1] || @input.bytesize
                opener = @input.byteindex(/\[quote=/i, range.begin)
                next if opener.nil? || opener >= line_end

                # A header that parses but has no username has nothing to
                # remap; core renders it without coordinates. A header the
                # grammar could not read at all may still hold remappable
                # fields, so it refuses instead of keeping stale data.
                match = @scanner.quote_construct.detect_block_opener(@input, opener)
                if match
                  spans[[match.start_pos, match.end_pos]] ||= match
                elsif !@scanner.quote_construct.parseable_opener?(@input, opener)
                  return :unanchored
                end
              end

              nil
            end
          end
        end
      end
    end
  end
end
