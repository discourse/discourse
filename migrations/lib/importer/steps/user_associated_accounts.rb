# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserAssociatedAccounts < ::Migrations::Importer::CopyStep
    EMPTY_JSON_OBJECT = "{}"

    depends_on :users

    requires_mapping :username_by_id, "SELECT id, username FROM users WHERE id > 0"
    requires_mapping :primary_email_by_user_id, <<~SQL
      SELECT user_id, email
      FROM user_emails
      WHERE "primary" = TRUE AND user_id > 0
    SQL

    requires_set :existing_provider_uids, <<~SQL
      SELECT provider_name, provider_uid
      FROM user_associated_accounts
    SQL

    requires_set :existing_user_ids, <<~SQL
      SELECT provider_name, user_id
      FROM user_associated_accounts
      WHERE user_id IS NOT NULL
    SQL

    column_names %i[
                   provider_name
                   user_id
                   created_at
                   credentials
                   updated_at
                   info
                   last_used
                   provider_uid
                   extra
                 ]

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM user_associated_accounts
           JOIN mapped.ids mapped_user
             ON user_associated_accounts.user_id = mapped_user.original_id
                AND mapped_user.type = ?
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT user_associated_accounts.*,
             mapped_user.discourse_id              AS discourse_user_id,
             COALESCE(
               user_associated_accounts.last_used,
               users.last_seen_at,
               users.created_at
             )                                     AS last_used
      FROM user_associated_accounts
           JOIN mapped.ids mapped_user
             ON user_associated_accounts.user_id = mapped_user.original_id
                AND mapped_user.type = ?
           JOIN users ON users.original_id = user_associated_accounts.user_id
       ORDER BY user_associated_accounts.user_id,
                user_associated_accounts.provider_name
    SQL

    private

    def transform_row(row)
      provider_name = row[:provider_name]
      user_id = row[:discourse_user_id]

      return nil unless @existing_provider_uids.add?(provider_name, row[:provider_uid])
      return nil unless @existing_user_ids.add?(provider_name, user_id)

      row[:user_id] = user_id
      row[:last_used] ||= NOW

      row[:credentials] = EMPTY_JSON_OBJECT
      row[:extra] = EMPTY_JSON_OBJECT

      if row[:info].blank?
        row[:info] = Migrations::Database.to_json(
          { nickname: @username_by_id[user_id], email: @primary_email_by_user_id[user_id] },
        )
      end

      super
    end
  end
end
