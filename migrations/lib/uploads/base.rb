# frozen_string_literal: true

require "etc"
require "sqlite3"

module Migrations
  module Uploads
    class Base
      TRANSACTION_SIZE = 1000
      QUEUE_SIZE = 1000

      # TODO: Use IntermediateDatabase instead
      def create_connection(path)
        sqlite = SQLite3::Database.new(path, results_as_hash: true)
        sqlite.busy_timeout = 60_000 # 60 seconds
        sqlite.journal_mode = "WAL"
        sqlite.synchronous = "off"
        sqlite
      end

      def query(sql, db)
        db.prepare(sql).execute
      end
    end
  end
end
