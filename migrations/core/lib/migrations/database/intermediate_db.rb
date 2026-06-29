# frozen_string_literal: true

module Migrations
  module Database
    module IntermediateDB
      def self.setup(db_connection)
        close
        @db = db_connection
      end

      # Swaps the connection for the duration of the block. Unlike `setup`,
      # neither connection is closed, and the previous one is restored even
      # when the block raises.
      def self.with_connection(db_connection)
        previous_connection = @db
        @db = db_connection
        yield
      ensure
        @db = previous_connection
      end

      def self.insert(sql, *parameters)
        @db.insert(sql, parameters)
      end

      def self.merge_shard(shard_path)
        @db.merge_shard(shard_path)
      end

      def self.close
        @db.close if @db
      end
    end
  end
end
