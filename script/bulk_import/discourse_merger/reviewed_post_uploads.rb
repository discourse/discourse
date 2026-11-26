# frozen_string_literal: true

require_relative "configuration"

module BulkImport::DiscourseMerge
  module ReviewedPostUploads
    def self.pattern(urls)
      /\G(?:#{Regexp.union(urls)})(?=\z|[\s"'<>)\]])/
    end

    def self.capture(connection, entries)
      raise Error, "preserved_broken_post_uploads must be an array" unless entries.is_a?(Array)
      entries
        .map do |entry|
          unless entry.is_a?(Hash) && entry["source_post_id"].is_a?(Integer) &&
                   entry["source_post_id"].positive? && entry["url"].is_a?(String) &&
                   entry["url"].match?(%r{\Aupload://[A-Za-z0-9][A-Za-z0-9_.-]*\z})
            raise Error,
                  "Each preserved broken upload needs a source post ID and an exact upload:// URL"
          end
          id, url = entry.values_at("source_post_id", "url")
          post =
            connection.exec_params(
              "SELECT topic_id, raw, cooked FROM posts WHERE id=$1",
              [id],
            ).first
          unless post &&
                   %w[raw cooked].all? { |key|
                     Digest::SHA256.hexdigest(post[key].to_s) == entry["#{key}_sha256"]
                   } &&
                   %w[raw cooked].any? { |key|
                     post[key].to_s.match?(%r{(?<![\w/.:])#{Regexp.escape(url)}(?=\z|[\s"'<>)\]])})
                   }
            raise Error, "Reviewed broken upload or post contents changed for source post #{id}"
          end
          entry.slice("source_post_id", "url", "raw_sha256", "cooked_sha256").merge(
            "source_topic_id" => Integer(post.fetch("topic_id")),
          )
        end
        .uniq
        .sort_by { |entry| entry.values_at("source_post_id", "url") }
    end
  end
end
