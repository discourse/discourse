# frozen_string_literal: true

require "digest/xxhash"

module Migrations
  module ID
    # Content-hash id for upload sources. It's stored as a 16-byte BLOB, so this
    # returns the raw digest as a binary string (`.b` gives it ASCII-8BIT
    # encoding, which Extralite binds as a BLOB and `to_blob` needs to avoid an
    # "invalid byte sequence" from `blank?`).
    #
    # The blob storage is coupled to a few places that must stay in sync:
    #   * schema columns typed `:blob` — `upload_sources.id`, `post_uploads.upload_id`
    #     and every `*upload*_id` reference (see the `.*upload.*_id$` convention and
    #     the table definitions under tooling/config/schema/intermediate_db)
    #   * the hand-written uploads.db schema (`uploads.id`, `optimized_images.id`,
    #     `downloads.id`)
    def self.hash(value)
      Digest::XXH3_128bits.digest(value).b
    end

    def self.build(part1, part2, *others)
      [part1, part2, *others].join("-")
    end
  end
end
