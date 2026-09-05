# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # One folded copy of a post body, with the byte map back to the raw.
        #
        # The engine reports a folded spelling for a name: it lowercases an
        # emoji shortcode and a hashtag slug before it looks either up. Both
        # sides therefore go through {.fold} — a fold at least as coarse as the
        # engine's is what count matching needs (see {MarkdownScanner}).
        #
        # The map back is per grapheme cluster: composition and case mapping
        # both stay inside one cluster, so a cluster's folded bytes belong to
        # exactly that cluster's raw bytes. A folded hit that does not start and
        # end on cluster boundaries denotes no raw span and is dropped, which
        # can only lower the count and so only ever escalates.
        class FoldedText
          # @param text [String]
          # @return [String] the folded spelling
          def self.fold(text)
            # NFC leaves ASCII alone, and most bodies are ASCII.
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

          # @param offset [Integer] byte offset into {#text}
          # @param length [Integer] byte length within {#text}
          # @return [Array(Integer, Integer), nil] the raw offset and length, or
          #   nil when the folded span crosses a cluster boundary
          def raw_span(offset, length)
            return offset, length if @cluster_starts.nil?
            return nil unless cluster_start?(offset)

            last = offset + length - 1
            return nil unless offset + length == @text.bytesize || cluster_start?(offset + length)

            start = @cluster_starts[offset]
            [start, @cluster_starts[last] + @cluster_lengths[last] - start]
          end

          private

          # Cluster raw offsets rise strictly, so a change in the recorded raw
          # offset marks a cluster boundary.
          def cluster_start?(offset)
            offset.zero? || @cluster_starts[offset] != @cluster_starts[offset - 1]
          end

          # Records, for every folded byte, where its cluster starts in the raw
          # and how long it is there. A cluster whose fold is empty contributes
          # no folded byte, so no occurrence can span its raw bytes.
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
