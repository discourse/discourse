# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # One folded copy of a post body, with the byte map back to the raw.
        #
        # Counting looks for the values the engine reported in the raw bytes,
        # and for names the engine reports a folded spelling: it lowercases an
        # emoji shortcode and a hashtag slug before it looks either up. A
        # counter that folds at least as coarsely as the engine can never see
        # fewer raw occurrences than the engine made tokens, which is what
        # keeps count matching sound — so both sides go through {.fold}, the
        # same NFC-then-downcase the source's name sets and the importer's
        # resolution use.
        #
        # The map back is per grapheme cluster: composition and case mapping
        # both stay inside one cluster, so a cluster's folded bytes belong to
        # exactly that cluster's raw bytes. A folded hit that does not start
        # and end on cluster boundaries denotes no raw span and is dropped,
        # which can only lower the count and so only ever escalates.
        class FoldedText
          # @param text [String]
          # @return [String] the folded spelling
          def self.fold(text)
            # NFC leaves ASCII alone, so an ASCII-only string needs only the
            # case mapping — and most bodies and every built-in name are ASCII.
            text.ascii_only? ? text.downcase : Migrations::NameNormalizer.normalize(text)
          end

          # @param raw [String] the post body
          def initialize(raw)
            @raw = raw
            if raw.ascii_only?
              @text = raw.downcase
            else
              build_map
            end
          end

          # @return [String] the whole body, folded
          attr_reader :text

          # The raw span a folded span denotes.
          #
          # @param offset [Integer] byte offset into {#text}
          # @param length [Integer] byte length within {#text}
          # @return [Array(Integer, Integer), nil] the raw offset and length,
          #   or nil when the folded span crosses a cluster boundary
          def raw_span(offset, length)
            return offset, length if @cluster_starts.nil?
            return nil unless cluster_start?(offset)

            last = offset + length - 1
            return nil unless offset + length == @text.bytesize || cluster_start?(offset + length)

            start = @cluster_starts[offset]
            [start, @cluster_starts[last] + @cluster_lengths[last] - start]
          end

          private

          # Whether the folded byte at `offset` is the first of its cluster.
          # Cluster raw offsets rise strictly, so a change in the recorded raw
          # offset marks the boundary.
          def cluster_start?(offset)
            offset.zero? || @cluster_starts[offset] != @cluster_starts[offset - 1]
          end

          # Folds cluster by cluster and records, for every folded byte, where
          # its cluster starts in the raw and how long it is there. A cluster
          # whose fold is empty contributes no folded byte, so its raw bytes
          # belong to no folded span and no occurrence can span them.
          def build_map
            @text = +""
            @cluster_starts = []
            @cluster_lengths = []
            offset = 0

            @raw.each_grapheme_cluster do |cluster|
              length = cluster.bytesize
              folded = FoldedText.fold(cluster)
              folded.bytesize.times do
                @cluster_starts << offset
                @cluster_lengths << length
              end
              @text << folded
              offset += length
            end
          end
        end
      end
    end
  end
end
