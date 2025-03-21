# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserEmails < ::Migrations::Importer::CopyStep
    depends_on :users

    column_names %i[user_id email primary created_at updated_at]

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM user_emails ue
        JOIN x.mappings mu ON ue.user_id = mu.original_id AND mu.type = ?
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT ue.email, ue."primary", ue.created_at, mu.discourse_id AS user_id
      FROM user_emails ue
        JOIN x.mappings mu ON ue.user_id = mu.original_id AND mu.type = ?
      ORDER BY ue.ROWID
    SQL
  end
end
