# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users
    TABLE_NAME = :users
    COLUMN_NAMES = %i[
      id
      username
      username_lower
      name
      active
      trust_level
      admin
      moderator
      date_of_birth
      ip_address
      registration_ip_address
      primary_group_id
      suspended_at
      suspended_till
      last_seen_at
      last_emailed_at
      created_at
      updated_at
    ]

    NOW = "NOW()"

    SQL = <<~SQL
      SELECT *
      FROM users
      ORDER BY rowid
    SQL

    def initialize(intermediate_db, discourse_db)
      @intermediate_db = intermediate_db
      @discourse_db = discourse_db
      @last_id = discourse_db.last_id_of(TABLE_NAME)
    end

    def execute
      puts "Importing users"
      @discourse_db.copy_data(TABLE_NAME, COLUMN_NAMES, query(SQL))
      @discourse_db.fix_last_id_of(TABLE_NAME)
    end

    private

    def query(sql, *parameters)
      Enumerator.new do |y|
        @intermediate_db.query(sql, *parameters) { |row| y << process_row(row) }
      end
    end

    def process_row(row)
      set_id(row)
      set_dates(row)

      row[:username] = row[:username].unicode_normalize!
      row[:username_lower] = row[:username].downcase
      row
    end

    def set_id(row)
      row[:original_id] = row[:id]
      row[:id] = @last_id += 1
    end

    def set_dates(row)
      row[:created_at] ||= NOW
      row[:updated_at] ||= NOW
    end
  end
end
