# frozen_string_literal: true

module Migrations::Uploader
  class Uploads
    attr_reader :settings, :databases

    def initialize(settings)
      @settings = settings

      @uploads_db = ::Migrations::IntermediateDB::Connection.new(path: @settings[:output_db_path])
      @intermediate_db =
        ::Migrations::IntermediateDB::Connection.new(path: @settings[:source_db_path])

      @databases = { uploads_db: @uploads_db, intermediate_db: @intermediate_db }

      # disable logging for EXIFR which is used by ImageOptim
      EXIFR.logger = Logger.new(nil)
      SiteSettings.configure!(settings[:site_settings])
      initialize_uploads_db
    end

    def perform!
      Tasks::Fixer.run!(databases, settings) if settings[:fix_missing]
      Tasks::Uploader.run!(databases, settings)
      Tasks::Optimizer.run!(databases, settings) if settings[:create_optimized_images]
    end

    def self.perform!(settings = {})
      new(settings).perform!
    end

    private

    def initialize_uploads_db
      @uploads_db.db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS uploads (
          id TEXT PRIMARY KEY NOT NULL,
          upload JSON_TEXT,
          markdown TEXT,
          skip_reason TEXT
        )
      SQL

      @uploads_db.db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS optimized_images (
          id TEXT PRIMARY KEY NOT NULL,
          optimized_images JSON_TEXT
        )
      SQL
    end
  end
end
