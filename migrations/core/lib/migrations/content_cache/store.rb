# frozen_string_literal: true

require "digest"
require "securerandom"

module Migrations
  module ContentCache
    class Store
      FORMAT_VERSION = 1
      SCHEMA_PATH = File.expand_path("../../../db/content_cache_schema", __dir__)

      def self.digest(*values)
        Digest::SHA256.hexdigest(JSON.generate(values))
      end

      def self.write(path, metadata)
        path = File.expand_path(path)
        temporary_path = "#{path}.#{SecureRandom.hex(8)}.tmp"
        Database.migrate(temporary_path, migrations_path: SCHEMA_PATH)
        store = new(temporary_path, writing: true)
        begin
          metadata
            .merge("format_version" => FORMAT_VERSION)
            .each do |key, value|
              store.connection.insert(
                "INSERT INTO metadata (key, value) VALUES (?, ?)",
                [key, JSON.generate(value)],
              )
            end
          yield store
          store.connection.commit_transaction
          store.connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
          store.close
          File.rename(temporary_path, path)
        ensure
          store.close
          Database.delete_database(temporary_path)
        end
      end

      attr_reader :connection, :metadata

      def initialize(path, writing: false)
        raise ArgumentError, "Content cache not found: #{path}" unless File.file?(path)
        @connection = Database.connect(File.expand_path(path))
        return if writing

        @connection.execute("PRAGMA query_only = ON")
        @metadata =
          @connection
            .query("SELECT key, value FROM metadata")
            .to_h { |row| [row[:key], JSON.parse(row[:value])] }
        unless @metadata["format_version"] == FORMAT_VERSION
          raise ArgumentError, "Unsupported content cache format"
        end
      rescue StandardError
        close
        raise
      end

      def put(kind, original_id, source_hash, payload)
        @connection.insert(
          "INSERT INTO entries (kind, original_id, source_hash, payload) VALUES (?, ?, ?, ?)",
          [kind, original_id.to_s, source_hash, JSON.generate(payload)],
        )
      end

      def get(kind, original_id, source_hash)
        payload =
          @connection.query_value(
            "SELECT payload FROM entries WHERE kind = ? AND original_id = ? AND source_hash = ?",
            kind,
            original_id.to_s,
            source_hash,
          )
        JSON.parse(payload) if payload
      end

      def close
        @connection&.close unless @connection&.closed?
      end
    end
  end
end
