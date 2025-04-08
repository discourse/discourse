# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module UserSuspension
    SQL = <<~SQL
      INSERT INTO user_suspensions (
        user_id,
        suspended_at,
        suspended_till,
        suspended_by_id,
        reason
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(user_id:, suspended_at:, suspended_till: nil, suspended_by_id: nil, reason: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        ::Migrations::Database.format_datetime(suspended_at),
        ::Migrations::Database.format_datetime(suspended_till),
        suspended_by_id,
        reason,
      )
    end
  end
end
