# frozen_string_literal: true

module Migrations::IntermediateDb
  module LogEntry
    SQL = <<~SQL
      INSERT INTO log_entries (created_at, type, message, exception, details)
      VALUES (?, ?, ?, ?, ?)
    SQL

    def self.create!(created_at: Time.now, type:, message:, exception: nil, details: nil)
      Migrations::IntermediateDb.insert(
        SQL,
        [
          Migrations::Database::Formatter.format_datetime(created_at),
          type,
          message,
          exception&.full_message(highlight: false),
          details,
        ],
      )
    end
  end
end
