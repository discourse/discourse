# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserEmails < ::Migrations::Importer::CopyStep
    depends_on :users

    requires_set :existing_user_ids, "SELECT DISTINCT user_id FROM user_emails"

    column_names %i[user_id email primary created_at updated_at]

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM users u
           JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?
           LEFT JOIN user_emails ue ON u.original_id = ue.user_id
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT mu.discourse_id                       AS user_id,
             ue.email,
             COALESCE(ue."primary", TRUE)          AS "primary",
             COALESCE(ue.created_at, u.created_at) AS created_at
      FROM users u
           JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?
           LEFT JOIN user_emails ue ON u.original_id = ue.user_id
      ORDER BY ue.user_id, ue.email
    SQL

    private

    def transform_row(row)
      return nil if @existing_user_ids.include?(row[:user_id])

      row[:email] ||= "#{SecureRandom.hex}@email.invalid"

      super
    end
  end
end
