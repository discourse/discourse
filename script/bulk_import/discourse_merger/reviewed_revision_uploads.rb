# frozen_string_literal: true

require_relative "configuration"

module BulkImport::DiscourseMerge
  module ReviewedRevisionUploads
    # Allow individual media references. A URL prefix would also exempt unreviewed files.
    MEDIA_URL =
      %r{\A(?:upload://[\w.-]+|(?:(?:https?:)?//[\w.-]+(?::\d+)?)?/(?:uploads/(?:short-url/[\w.-]+|[\w.-]+/(?:original|optimized)/\d+X/[\w./%-]+)|user_avatar/[\w.%/-]+/\d+/\d+(?:_\d+)?\.png))\z}

    def self.pattern(urls)
      %r{(?<![\w/.:])(#{Regexp.union(urls.sort_by { |url| -url.size })})(?![\w./%?#&=~+\-])}
    end

    def self.capture(connection, entries)
      raise Error, "preserved_broken_revision_uploads must be an array" unless entries.is_a?(Array)
      seen = Set.new
      entries
        .map do |entry|
          id, digest, urls =
            entry.values_at("source_revision_id", "modifications_sha256", "urls") if entry.is_a?(
            Hash,
          )
          unless id.is_a?(Integer) && id.positive? && seen.add?(id) && urls.is_a?(Array) &&
                   urls.any? && urls.all? { |url| url.is_a?(String) && MEDIA_URL.match?(url) }
            raise Error,
                  "Each reviewed revision needs a unique source revision ID and exact media URLs"
          end
          source = connection.exec_params(<<~SQL, [id]).first
          SELECT p.topic_id, r.post_id, r.modifications FROM post_revisions r
          JOIN posts p ON p.id=r.post_id WHERE r.id=$1
        SQL
          unless source && Digest::SHA256.hexdigest(source.fetch("modifications").to_s) == digest &&
                   urls.all? { |url| source.fetch("modifications").include?(url) }
            raise Error, "Reviewed media or contents changed for source revision #{id}"
          end
          {
            "source_revision_id" => id,
            "source_post_id" => Integer(source.fetch("post_id")),
            "source_topic_id" => Integer(source.fetch("topic_id")),
            "modifications_sha256" => digest,
            "urls" => urls.uniq.sort,
          }
        end
        .sort_by { |entry| entry.fetch("source_revision_id") }
    end
  end
end
