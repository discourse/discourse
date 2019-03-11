module Jobs
  class IgnoredUsersSummary < Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.ignore_user_enabled

      user_ids = DB.query_single <<~SQL
        SELECT u.id AS user_id
        FROM users AS u
        INNER JOIN ignored_users AS ig ON ig.ignored_user_id = u.id
        GROUP BY u.id
        HAVING COUNT(u.id) >= #{SiteSetting.ignored_users_count_message_threshold}
      SQL

      User.where(id: user_ids).find_each { |user| notify_user(user) if should_notify_user?(user) }
    end

    private

    def should_notify_user?(user)
      custom_field = PostCustomField.where("name = 'summary_sent_for_ignored_user' AND value = ?", user.id.to_s).select(:created_at).first
      custom_field.blank? || (custom_field.created_at - SiteSetting.ignored_users_message_gap_days.days) > Time.now.utc
    end

    def notify_user(user)
      params = SystemMessage.new(User.last).defaults.merge({ignores_threshold: SiteSetting.ignored_users_count_message_threshold})
      title = I18n.t("system_messages.ignored_users_summary.subject_template")
      raw = I18n.t("system_messages.ignored_users_summary.text_body_template", params)

      PostCreator.create(
        Discourse.system_user,
        target_group_names: Group[:moderators].name,
        archetype: Archetype.private_message,
        subtype: TopicSubtype.system_message,
        title: title,
        raw: raw,
        skip_validations: true,
        custom_fields: {summary_sent_for_ignored_user: user.id.to_s})
    end
  end
end
