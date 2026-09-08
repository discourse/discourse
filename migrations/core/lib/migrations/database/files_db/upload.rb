# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module Upload
        SQL = <<~SQL
          INSERT INTO uploads (
            id,
            animated,
            created_at,
            dominant_color,
            etag,
            extension,
            filesize,
            height,
            origin,
            original_filename,
            original_sha1,
            secure,
            security_last_changed_at,
            security_last_changed_reason,
            sha1,
            thumbnail_height,
            thumbnail_width,
            url,
            verification_status,
            width
          )
          VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `uploads` record in the FilesDB.
        #
        # @param id                             [Integer]
        # @param animated                       [Boolean, nil]
        # @param created_at                     [Time, nil]
        # @param dominant_color                 [String, nil]
        # @param etag                           [String, nil]
        # @param extension                      [String, nil]
        # @param filesize                       [Integer]
        # @param height                         [Integer, nil]
        # @param origin                         [String, nil]
        # @param original_filename              [String]
        # @param original_sha1                  [String, nil]
        # @param secure                         [Boolean, nil]
        # @param security_last_changed_at       [Time, nil]
        # @param security_last_changed_reason   [String, nil]
        # @param sha1                           [String, nil]
        # @param thumbnail_height               [Integer, nil]
        # @param thumbnail_width                [Integer, nil]
        # @param url                            [String]
        # @param verification_status            [Integer, nil]
        # @param width                          [Integer, nil]
        #
        # @return [void]
        def self.create(
          id:,
          animated: nil,
          created_at: nil,
          dominant_color: nil,
          etag: nil,
          extension: nil,
          filesize:,
          height: nil,
          origin: nil,
          original_filename:,
          original_sha1: nil,
          secure: nil,
          security_last_changed_at: nil,
          security_last_changed_reason: nil,
          sha1: nil,
          thumbnail_height: nil,
          thumbnail_width: nil,
          url:,
          verification_status: nil,
          width: nil
        )
          Migrations::Database::FilesDB.insert(
            SQL,
            id,
            Migrations::Database.format_boolean(animated),
            Migrations::Database.format_datetime(created_at),
            dominant_color,
            etag,
            extension,
            filesize,
            height,
            origin,
            original_filename,
            original_sha1,
            Migrations::Database.format_boolean(secure),
            Migrations::Database.format_datetime(security_last_changed_at),
            security_last_changed_reason,
            sha1,
            thumbnail_height,
            thumbnail_width,
            url,
            verification_status,
            width,
          )
        end
      end
    end
  end
end
