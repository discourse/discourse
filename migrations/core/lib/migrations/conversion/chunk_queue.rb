# frozen_string_literal: true

module Migrations
  module Conversion
    # A shared bag of chunk indices for the forked workers of a partitioned step.
    # The parent fills a pipe with every chunk's index and closes it; each worker
    # reads the next one when it goes idle, so a fork with cheap chunks keeps
    # pulling more and the slow forks don't drag out the end.
    #
    # The workers coordinate per chunk, not per row: one small read when a worker
    # needs the next chunk, a few hundred for a whole step.
    #
    # The reads are unbuffered and fixed width, so several forks reading the one
    # pipe each take a whole index and never split one. The whole bag fits in the
    # pipe buffer, so the fill never blocks and every read returns a full index
    # until the bag is empty.
    class ChunkQueue
      # Digits per index. Eight is more than enough for any chunk count.
      WIDTH = 8

      # Fills a fresh queue with the indices `0...count`.
      def self.filled(count)
        reader, writer = IO.pipe
        count.times { |index| writer.write(format("%0#{WIDTH}d", index)) }
        writer.close
        new(reader)
      end

      def initialize(reader)
        @reader = reader
      end

      # The next chunk index, or nil once the bag is empty. Safe to call from
      # several forked workers at once: each unbuffered read takes one whole index.
      def claim
        @reader.sysread(WIDTH).to_i
      rescue EOFError
        nil
      end

      def close
        @reader.close
      end
    end
  end
end
