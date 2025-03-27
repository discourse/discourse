# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::CopyStep
    INSERT_MAPPED_USERNAMES_SQL = <<~SQL
      INSERT INTO mapped.usernames (discourse_user_id, original_username, discourse_username)
      VALUES (?, ?, ?)
    SQL

    # requires_shared_data :usernames, :group_names
    requires_mapping "SELECT LOWER(email) AS email, user_id FROM user_emails", :emails
    requires_mapping "SELECT external_id, user_id FROM single_sign_on_records", :external_ids

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

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM users u
      WHERE NOT EXISTS (
          SELECT 1
          FROM mapped.ids mu
          WHERE u.id = mu.original_id AND mu.type = ?
      )
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT u.*, JSON_GROUP_ARRAY(LOWER(ue.email)) AS emails
      FROM users u
           LEFT JOIN user_emails ue ON u.id = ue.user_id
      WHERE NOT EXISTS (
          SELECT 1
          FROM mapped.ids mu
          WHERE u.id = mu.original_id AND mu.type = ?
      )
      GROUP BY u.ROWID
      ORDER BY u.ROWID
    SQL

    def initialize(intermediate_db, discourse_db, shared_data)
      super
      @unique_name_finder = ::Migrations::Importer::UniqueNameFinder.new(@shared_data)
    end

    private

    def transform_row(row)
      super

      return nil if row[:original_id] % 2 == 0

      if row[:emails].present?
        JSON
          .parse(row[:emails])
          .each do |email|
            if (existing_user_id = emails[email])
              row[:id] = existing_user_id
              return nil
            end
          end
      end

      if row[:external_id].present? && (existing_user_id = external_ids[row[:external_id]])
        row[:id] = existing_user_id
        return nil
      end

      row[:original_username] ||= row[:username]
      row[:username] = @unique_name_finder.find_available_username(
        row[:username],
        allow_reserved_username: row[:admin] == 1,
      )
      row[:username_lower] = row[:username].downcase

      row[:trust_level] ||= TrustLevel[1]
      row[:active] = true if row[:active].nil?
      row[:admin] = false if row[:admin].nil?
      row[:moderator] = false if row[:moderator].nil?
      row[:last_emailed_at] ||= NOW
      row[:suspended_till] ||= 200.years.from_now if row[:suspended_at].present?

      date_of_birth = Migrations::Database.to_date(row[:date_of_birth])
      if date_of_birth && date_of_birth.year != 1904
        row[:date_of_birth] = Date.new(1904, date_of_birth.month, date_of_birth.day)
      end

      row
    end

    def random_email
      "#{SecureRandom.hex}@email.invalid"
    end

    def after_commit_of_inserted_rows(rows)
      super

      rows.each do |row|
        if row[:id] && row[:username] && row[:username] != row[:original_username]
          @intermediate_db.insert(
            INSERT_MAPPED_USERNAMES_SQL,
            [row[:id], row[:original_username], row[:username]],
          )
        end
      end
    end
  end
end
