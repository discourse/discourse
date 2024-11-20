# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module LogEntry
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"

    SQL = <<~SQL
      INSERT INTO log_entries (created_at, type, message, exception, details)
      VALUES (?, ?, ?, ?, ?)
    SQL

    def self.create!(created_at: Time.now, type:, message:, exception: nil, details: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        ::Migrations::Database.format_datetime(created_at),
        type,
        message,
        exception&.full_message(highlight: false),
        ::Migrations::Database.to_json(details),
      )
    end
  end
end
