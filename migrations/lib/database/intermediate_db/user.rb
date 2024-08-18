# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module User
    SQL = <<~SQL
      INSERT INTO users (created_at, type, message, exception, details)
      VALUES (?, ?, ?, ?, ?)
    SQL

    def self.create!(created_at: Time.now, type:, message:, exception: nil, details: nil)
    end
  end
end
