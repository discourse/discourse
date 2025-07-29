# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module PermalinkPlaceholder
    SQL = <<~SQL
      INSERT INTO permalink_placeholders (
        url,
        placeholder,
        target_type,
        target_id
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(url:, target_type:, target_id:)
      placeholder = ::Migrations::ID.hash("#{target_type}-#{target_id}")
      ::Migrations::Database::IntermediateDB.insert(SQL, url, placeholder, target_type, target_id)

      placeholder
    end
  end
end
