# frozen_string_literal: true

module Jobs
  class OldKeysReminder < ::Jobs::Scheduled
    every 1.month

    OLD_CREDENTIALS_PERIOD = 2.years

    def execute(_args)
      return if SiteSetting.send_old_credential_reminder_days.to_i == 0
      return if message_exists?
      return if old_site_settings_keys.blank? && old_api_keys.blank?

      PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: body,
        archetype: Archetype.private_message,
        target_usernames: admins.map(&:username),
        validate: false,
      )
    end

    private

    def old_site_settings_keys
      @old_site_settings_keys ||=
        SiteSetting
          .secret_settings
          .each_with_object([]) do |secret_name, old_keys|
            site_setting = SiteSetting.find_by(name: secret_name)
            next if site_setting&.value.blank?
            next if site_setting.updated_at + OLD_CREDENTIALS_PERIOD > Time.zone.now
            old_keys << site_setting
          end
          .sort_by { |key| key.updated_at }
    end

    def old_api_keys
      @old_api_keys ||=
        ApiKey
          .all
          .order(created_at: :asc)
          .each_with_object([]) do |api_key, old_keys|
            next if api_key.created_at + OLD_CREDENTIALS_PERIOD > Time.zone.now
            old_keys << api_key
          end
    end

    def admins
      User.real.admins
    end

    def message_exists?
      message = Topic.private_messages.with_deleted.find_by(title: title)
      message &&
        message.created_at + SiteSetting.send_old_credential_reminder_days.to_i.days > Time.zone.now
    end

    def title
      I18n.t("old_keys_reminder.title")
    end

    def body
      I18n.t("old_keys_reminder.body", keys: keys_list)
    end

    def keys_list
      messages =
        old_site_settings_keys.map { |key| "#{key.name} - #{key.updated_at.to_date.to_fs(:db)}" }
      old_api_keys.each_with_object(messages) do |key, array|
        array << "#{[key.description, key.user&.username, key.created_at.to_date.to_fs(:db)].compact.join(" - ")}"
      end
      messages.join("\n")
    end
  end
end
