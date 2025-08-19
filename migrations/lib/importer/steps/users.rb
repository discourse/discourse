# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::CopyStep
    INSERT_MAPPED_USERNAMES_SQL = <<~SQL
      INSERT INTO mapped.usernames (discourse_user_id, original_username, discourse_username)
      VALUES (?, ?, ?)
    SQL

    # requires_shared_data :usernames, :group_names
    requires_mapping :user_ids_by_email, "SELECT LOWER(email) AS email, user_id FROM user_emails"
    requires_mapping :user_ids_by_external_id,
                     "SELECT external_id, user_id FROM single_sign_on_records"

    table_name :users
    column_names %i[
                   id
                   username
                   username_lower
                   name
                   active
                   trust_level
                   group_locked_trust_level
                   manual_locked_trust_level
                   admin
                   moderator
                   date_of_birth
                   locale
                   ip_address
                   registration_ip_address
                   primary_group_id
                   flair_group_id
                   suspended_at
                   suspended_till
                   first_seen_at
                   last_seen_at
                   last_emailed_at
                   silenced_till
                   approved
                   approved_at
                   approved_by_id
                   views
                   created_at
                   updated_at
                 ]

    store_mapped_ids true

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM users u
           LEFT JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?
      WHERE mu.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT u.*,
             us.suspended_at,
             us.suspended_till,
             GROUP_CONCAT(LOWER(ue.email)) AS emails
      FROM users u
           LEFT JOIN user_emails ue ON u.original_id = ue.user_id
           LEFT JOIN mapped.ids amu ON u.approved_by_id IS NOT NULL AND u.approved_by_id = amu.original_id AND amu.type = ?1
           LEFT JOIN user_suspensions us ON u.original_id = us.user_id AND us.suspended_at < DATETIME() AND
                                            (us.suspended_till IS NULL OR us.suspended_till > DATETIME())
           LEFT JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?1
      WHERE mu.original_id IS NULL
      GROUP BY u.original_id
      ORDER BY u.ROWID
    SQL

    def initialize(intermediate_db, discourse_db, shared_data)
      super
      @unique_name_finder = ::Migrations::Importer::UniqueNameFinder.new(@shared_data)
    end

    private

    def transform_row(row)
      if row[:emails].present?
        emails = row[:emails].split(",")
        emails.each do |email|
          if (existing_user_id = @user_ids_by_email[email])
            row[:id] = existing_user_id
            return nil
          end
        end
      end

      if row[:external_id].present? &&
           (existing_user_id = @user_ids_by_external_id[row[:external_id]])
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
      row[:staged] = false if row[:staged].nil?

      row[:last_emailed_at] ||= NOW
      row[:suspended_till] ||= 200.years.from_now if row[:suspended_at].present?

      date_of_birth = Migrations::Database.to_date(row[:date_of_birth])
      if date_of_birth && date_of_birth.year != 1904
        row[:date_of_birth] = Date.new(1904, date_of_birth.month, date_of_birth.day)
      end

      if SiteSetting.must_approve_users || !row[:approved].nil?
        row[:approved] = true if row[:approved].nil?
        row[:approved_at] = row[:approved] ? row[:approved_at] || NOW : nil
        row[:approved_by_id] = row[:approved] ? row[:approved_by_id] || SYSTEM_USER_ID : nil
      end

      row[:views] ||= 0

      # we need to set it in a different step because `uploads` depends on `users`
      row.delete(:uploaded_avatar_id)

      super

      emails&.each { |email| @user_ids_by_email[email] = row[:id] }
      @user_ids_by_external_id[row[:external_id]] = row[:id]

      row
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
