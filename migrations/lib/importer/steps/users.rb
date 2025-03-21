# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::CopyStep
    table_name :users
    column_names %i[
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

    store_mapped_ids true

    total_rows_query <<~SQL
      SELECT COUNT(*)
      FROM users
    SQL

    rows_query <<~SQL
      SELECT u.*, JSON_GROUP_ARRAY(ue.email) AS emails
      FROM users u
           LEFT JOIN user_emails ue ON u.id = ue.user_id
      GROUP BY u.ROWID
      ORDER BY u.ROWID
    SQL

    private

    def transform_row(row)
      emails = JSON.parse(row[:emails])

      row[:username] = row[:username].unicode_normalize!
      row[:username_lower] = row[:username].downcase

      super
    end
  end
end
