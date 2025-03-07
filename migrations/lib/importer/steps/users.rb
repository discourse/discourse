# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::Step
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

    SQL = <<~SQL
      SELECT *
      FROM users
      ORDER BY rowid
    SQL

    def initialize(intermediate_db, discourse_db)
      super
      @last_id = discourse_db.last_id_of(TABLE_NAME)
    end

    def execute
      puts "Importing users"
      @discourse_db.copy_data(TABLE_NAME, COLUMN_NAMES, query(SQL))
      @discourse_db.fix_last_id_of(TABLE_NAME)
    end

    private

    def process_row(row)
      set_id(row)
      set_dates(row)

      @intermediate_db.insert(INSERT_MAPPING_SQL, [row[:original_id], MAPPING_TYPE, row[:id]])

      row[:username] = row[:username].unicode_normalize!
      row[:username_lower] = row[:username].downcase
      row
    end

    INSERT_MAPPING_SQL = <<~SQL
      INSERT INTO x.mappings (original_id, type, discourse_id)
      VALUES (?, ?, ?)
    SQL
    MAPPING_TYPE = 1
  end
end
