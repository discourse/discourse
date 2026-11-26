# frozen_string_literal: true

module BulkImport::DiscourseMerge
  # Input is ordered by source topic, post, then link ID. Keep only one post in memory.
  class TopicLinkRows
    def initialize(&write)
      @write = write
      @urls = {}
    end

    def call(row)
      key = row.values_at("topic_id", "post_id")
      if key != @post
        flush
        @post = key
      end
      # PostgreSQL permits multiple topic-only links with a NULL post_id.
      return @write.call(row) unless row["post_id"]

      url = row.fetch("url")
      if (first = @urls[url])
        first["clicks"] = Integer(first.fetch("clicks")) + Integer(row.fetch("clicks"))
        return first
      end
      @urls[url] = row
    end

    def flush
      @urls.each_value { |row| @write.call(row) }
      @urls.clear
    end
  end
end
