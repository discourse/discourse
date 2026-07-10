# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module OptimizedImage
        SQL = <<~SQL
          INSERT INTO optimized_images (
            id,
            created_at,
            etag,
            extension,
            filesize,
            height,
            sha1,
            upload_id,
            url,
            version,
            width
          )
          VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `optimized_images` record in the FilesDB.
        #
        # @param id           [Integer]
        # @param created_at   [Time, nil]
        # @param etag         [String, nil]
        # @param extension    [String]
        # @param filesize     [Integer, nil]
        # @param height       [Integer]
        # @param sha1         [String]
        # @param upload_id    [Integer]
        # @param url          [String]
        # @param version      [Integer, nil]
        # @param width        [Integer]
        #
        # @return [void]
        def self.create(
          id:,
          created_at: nil,
          etag: nil,
          extension:,
          filesize: nil,
          height:,
          sha1:,
          upload_id:,
          url:,
          version: nil,
          width:
        )
          Migrations::Database::FilesDB.insert(
            SQL,
            id,
            Migrations::Database.format_datetime(created_at),
            etag,
            extension,
            filesize,
            height,
            sha1,
            upload_id,
            url,
            version,
            width,
          )
        end
      end
    end
  end
end
