# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserEmails < ::Migrations::Importer::Step
    depends_on :users

    TABLE_NAME = :user_emails
    COLUMN_NAMES = %i[user_id email primary created_at updated_at]

    SQL = <<~SQL
      SELECT ue.email, ue."primary", ue.created_at, mu.discourse_id AS user_id
      FROM user_emails ue
        JOIN x.mappings mu ON ue.user_id = mu.original_id AND mu.type = 1
      ORDER BY ue.rowid
    SQL

    def execute
      puts "Importing user_emails"
      @discourse_db.copy_data(TABLE_NAME, COLUMN_NAMES, query(SQL))
    end

    private

    def process_row(row)
      set_dates(row)
      row
    end
  end
end
