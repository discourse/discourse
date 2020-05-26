# frozen_string_literal: true

module Jobs
  class OldKeysReminder < ::Jobs::Scheduled
    every 1.month

    def execute(_args)
      return if SiteSetting.notify_about_secrets_older_than == 'never'
      return if old_site_settings_keys.blank? && old_api_keys.blank?
      admins.each do |admin|
        PostCreator.create!(
          Discourse.system_user,
          title: title,
          raw: body,
          archetype: Archetype.private_message,
          target_usernames: admin.username,
          validate: false
        )
      end
    end

    private

    def old_site_settings_keys
      @old_site_settings_keys ||= SiteSetting.secret_settings.each_with_object([]) do |secret_name, old_keys|
        site_setting = SiteSetting.find_by(name: secret_name)
        next if site_setting&.value.blank?
        next if site_setting.updated_at + calculate_period > Time.zone.now
        old_keys << site_setting
      end.sort_by { |key| key.updated_at }
    end

    def old_api_keys
      @old_api_keys ||= ApiKey.all.order(created_at: :asc).each_with_object([]) do |api_key, old_keys|
        next if api_key.created_at + calculate_period > Time.zone.now
        old_keys << api_key
      end
    end

    def calculate_period
      SiteSetting.notify_about_secrets_older_than.to_i.years
    end

    def admins
      User.real.admins
    end

    def title
      I18n.t('old_keys_reminder.title', keys_count: old_site_settings_keys.count + old_api_keys.count)
    end

    def body
      I18n.t('old_keys_reminder.body', keys: keys_list)
    end

    def keys_list
      messages = old_site_settings_keys.map { |key| "#{key.name} - #{key.updated_at}" }
      old_api_keys.each_with_object(messages) { |key, array| array << "#{[key.description, key.user&.username, key.created_at].compact.join(" - ")}" }
      messages.join("\n")
    end
  end
end
