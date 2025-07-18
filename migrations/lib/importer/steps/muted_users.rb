# frozen_string_literal: true

module Migrations::Importer::Steps
  class MutedUsers < ::Migrations::Importer::CopyStep
    depends_on :users

    column_names %i[muted_user_id user_id created_at]

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM muted_users
           JOIN mapped.ids mapped_users
             ON muted_users.user_id = mapped_users.original_id AND mapped_users.type = ?
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT muted_users.*,
             mapped_users.discourse_id AS discourse_user_id,
             mapped_muted_users.discourse_id AS discourse_muted_user_id
      FROM muted_users
           JOIN mapped.ids mapped_users
             ON muted_users.user_id = mapped_users.original_id AND mapped_users.type = ?
           JOIN mapped.ids mapped_muted_users
             ON muted_users.muted_user_id = mapped_muted_users.original_id AND mapped_muted_users.type = ?
      ORDER BY user_id, muted_user_id
    SQL

    def execute
      # TODO: Remove once SetStore is available
      @existing_muted_users = Hash.new { |h, k| h[k] = Set.new }

      @discourse_db
        .query_array("SELECT user_id, muted_user_id FROM muted_users")
        .each { |row| @existing_muted_users[row[0]].add(row[1]) }

      super
    end

    private

    def transform_row(row)
      user_id = row[:discourse_user_id]
      muted_user_id = row[:discourse_muted_user_id]

      return nil unless @existing_muted_users[user_id].add?(muted_user_id)

      row[:user_id] = user_id
      row[:muted_user_id] = muted_user_id

      super
    end
  end
end
