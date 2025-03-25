# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::CopyStep
    INSERT_MAPPED_USERNAMES_SQL = <<~SQL
      INSERT INTO mapped.usernames (discourse_user_id, original_username, discourse_username)
      VALUES (?, ?, ?)
    SQL

    # requires_shared_data :usernames, :group_names
    # requires_mapping "SELECT email, user_id FROM user_emails", :emails
    # requires_mapping "SELECT external_id, user_id FROM single_sign_on_records", :external_ids

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

    def initialize(intermediate_db, discourse_db, shared_data)
      super
      @unique_name_finder = ::Migrations::Importer::UniqueNameFinder.new(@shared_data)
    end

    private

    def transform_row(row)
      super

      return nil if row[:original_id] % 2 == 0

      emails = JSON.parse(row[:emails])

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
        if row[:username] && row[:username] != row[:original_username]
          @intermediate_db.insert(
            INSERT_MAPPED_USERNAMES_SQL,
            [row[:id], row[:original_username], row[:username]],
          )
        end
      end
    end

    def process_user(user)
      if user[:email].present?
        user[:email] = user[:email].downcase

        if (existing_user_id = @emails[user[:email]])
          @users[user[:imported_id].to_i] = existing_user_id
          user[:skip] = true
          return user
        end
      end

      if user[:external_id].present?
        if (existing_user_id = @external_ids[user[:external_id]])
          @users[user[:imported_id].to_i] = existing_user_id
          user[:skip] = true
          return user
        end
      end

      # @users[user[:imported_id].to_i] = user[:id] = @last_user_id += 1

      # imported_username = user[:original_username].presence || user[:username].dup

      # user[:username] = fix_name(user[:username]).presence || random_username

      # if user[:username] != imported_username
      #   @imported_usernames[imported_username] = user[:id]
      #   @mapped_usernames[imported_username] = user[:username]
      # end

      # # unique username_lower
      # if user_exist?(user[:username])
      #   username = user[:username] + "_1"
      #   username.next! while user_exist?(username)
      #   user[:username] = username
      # end

      # user[:username_lower] = user[:username].downcase
      # user[:trust_level] ||= TrustLevel[1]
      # user[:active] = true unless user.has_key?(:active)
      # user[:admin] ||= false
      # user[:moderator] ||= false
      # user[:last_emailed_at] ||= NOW
      # user[:created_at] ||= NOW
      # user[:updated_at] ||= user[:created_at]
      # user[:suspended_at] ||= user[:suspended_at]
      # user[:suspended_till] ||= user[:suspended_till] ||
      #   (200.years.from_now if user[:suspended_at].present?)

      # if (date_of_birth = user[:date_of_birth]).is_a?(Date) && date_of_birth.year != 1904
      #   user[:date_of_birth] = Date.new(1904, date_of_birth.month, date_of_birth.day)
      # end

      @user_ids_by_username_lower[user[:username_lower]] = user[:id]
      @usernames_by_id[user[:id]] = user[:username]
      @user_full_names_by_id[user[:id]] = user[:name] if user[:name].present?

      user
    end
  end
end
