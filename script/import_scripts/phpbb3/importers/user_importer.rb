# frozen_string_literal: true

require_relative "../support/constants"

module ImportScripts::PhpBB3
  class UserImporter
    # @param avatar_importer [ImportScripts::PhpBB3::AvatarImporter]
    # @param settings [ImportScripts::PhpBB3::Settings]
    def initialize(avatar_importer, settings)
      @avatar_importer = avatar_importer
      @settings = settings
    end

    def map_users_to_import_ids(rows)
      rows.map { |row| @settings.prefix(row[:user_id]) }
    end

    def map_user(row)
      is_active_user = row[:user_inactive_reason] != Constants::INACTIVE_REGISTER

      trust_level = row[:user_posts] == 0 ? TrustLevel[0] : TrustLevel[1]
      trust_level = @settings.trust_level_for_posts(row[:user_posts], trust_level: trust_level)
      manual_locked_trust_level = trust_level > TrustLevel[1] ? trust_level : nil

      {
        id: @settings.prefix(row[:user_id]),
        email: row[:user_email],
        username: row[:username],
        password: @settings.import_passwords ? row[:user_password] : nil,
        name: @settings.username_as_name ? row[:username] : row[:name].presence,
        created_at: Time.zone.at(row[:user_regdate]),
        last_seen_at:
          (
            if row[:user_lastvisit] == 0
              Time.zone.at(row[:user_regdate])
            else
              Time.zone.at(row[:user_lastvisit])
            end
          ),
        registration_ip_address:
          (
            begin
              IPAddr.new(row[:user_ip])
            rescue StandardError
              nil
            end
          ),
        active: is_active_user,
        trust_level: trust_level,
        manual_locked_trust_level: manual_locked_trust_level,
        approved: is_active_user,
        approved_by_id: is_active_user ? Discourse.system_user.id : nil,
        approved_at: is_active_user ? Time.now : nil,
        moderator: row[:group_name] == Constants::GROUP_MODERATORS,
        admin: row[:group_name] == Constants::GROUP_ADMINISTRATORS,
        website: row[:user_website],
        location: row[:user_from],
        date_of_birth: parse_birthdate(row),
        custom_fields: custom_fields(row),
        post_create_action:
          proc do |user|
            suspend_user(user, row)
            @avatar_importer.import_avatar(user, row) if row[:user_avatar_type].present?
          end,
      }
    end

    def map_anonymous_users_to_import_ids(rows)
      rows.map { |row| @settings.prefix(row[:post_username]) }
    end

    def map_anonymous_user(row)
      username = row[:post_username]

      {
        id: @settings.prefix(username),
        email: "anonymous_#{SecureRandom.hex}@no-email.invalid",
        username: username,
        name: @settings.username_as_name ? username : "",
        created_at: Time.zone.at(row[:first_post_time]),
        active: true,
        trust_level: TrustLevel[0],
        approved: true,
        approved_by_id: Discourse.system_user.id,
        approved_at: Time.now,
        post_create_action:
          proc do |user|
            row[:user_inactive_reason] = Constants::INACTIVE_MANUAL
            row[:ban_reason] = "Anonymous user from phpBB3" # TODO i18n
            suspend_user(user, row, true)
          end,
      }
    end

    protected

    def parse_birthdate(row)
      return nil if row[:user_birthday].blank?
      birthdate =
        begin
          Date.strptime(row[:user_birthday].delete(" "), "%d-%m-%Y")
        rescue StandardError
          nil
        end
      birthdate && birthdate.year > 0 ? birthdate : nil
    end

    def user_fields
      @user_fields ||=
        begin
          Hash[UserField.all.map { |field| [field.name, field] }]
        end
    end

    def field_mappings
      @field_mappings ||=
        begin
          @settings.custom_fields.map do |field|
            {
              phpbb_field_name: "pf_#{field[:phpbb_field_name]}".to_sym,
              discourse_user_field: user_fields[field[:discourse_field_name]],
            }
          end
        end
    end

    def custom_fields(row)
      return nil if @settings.custom_fields.blank?

      custom_fields = {}

      field_mappings.each do |field|
        value = row[field[:phpbb_field_name]]
        user_field = field[:discourse_user_field]

        case user_field.field_type
        when "confirm"
          value = value == 1 ? true : nil
        when "dropdown"
          value =
            user_field.user_field_options.find { |option| option.value == value } ? value : nil
        end

        custom_fields["user_field_#{user_field.id}"] = value if value.present?
      end

      custom_fields
    end

    # Suspends the user if it is currently banned.
    def suspend_user(user, row, disable_email = false)
      if row[:user_inactive_reason] == Constants::INACTIVE_MANUAL
        user.suspended_at = Time.now
        user.suspended_till = 200.years.from_now
        ban_reason =
          row[:ban_reason].blank? ? "Account deactivated by administrator" : row[:ban_reason] # TODO i18n
      elsif row[:ban_start].present?
        user.suspended_at = Time.zone.at(row[:ban_start])
        user.suspended_till = row[:ban_end] > 0 ? Time.zone.at(row[:ban_end]) : 200.years.from_now
        ban_reason = row[:ban_reason]
      else
        return
      end

      if disable_email
        user_option = user.user_option
        user_option.email_digests = false
        user_option.email_level = UserOption.email_level_types[:never]
        user_option.email_messages_level = UserOption.email_level_types[:never]
        user_option.save!
      end

      if user.save
        StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, ban_reason)
      else
        Rails.logger.error(
          "Failed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}",
        )
      end
    end
  end
end
