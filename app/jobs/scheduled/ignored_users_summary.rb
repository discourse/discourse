module Jobs
  class IgnoredUsersSummary < Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.ignore_user_enabled

      params = {
        threshold: SiteSetting.ignored_users_count_message_threshold,
        gap_days: SiteSetting.ignored_users_message_gap_days
      }
      user_ids = DB.query_single(<<~SQL, params)
        SELECT ig.ignored_user_id AS user_id
        FROM ignored_users AS ig
        WHERE NOT EXISTS (SELECT 1
                          FROM post_custom_fields as pcf
                          WHERE pcf.name = 'summary_sent_for_ignored_user'
                            AND pcf.value = user_id::text
                            AND pcf.created_at < CURRENT_TIMESTAMP - ':gap_days DAYS'::INTERVAL
        GROUP BY ig.ignored_user_id
        HAVING COUNT(ig.ignored_user_id) > :threshold
      SQL

      User.where(id: user_ids).find_each { |user| notify_user(user) }
    end

    private

    def notify_user(user)
      params = SystemMessage.new(user).defaults.merge({ ignores_threshold: SiteSetting.ignored_users_count_message_threshold })
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
        custom_fields: { summary_sent_for_ignored_user: user.id.to_s })
    end
  end
end
