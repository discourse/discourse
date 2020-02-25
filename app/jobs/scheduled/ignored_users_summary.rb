# frozen_string_literal: true

module Jobs
  class IgnoredUsersSummary < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      params = {
        threshold: SiteSetting.ignored_users_count_message_threshold,
        gap_days: SiteSetting.ignored_users_message_gap_days,
        coalesced_gap_days: SiteSetting.ignored_users_message_gap_days + 1,
      }
      user_ids = DB.query_single(<<~SQL, params)
        SELECT ignored_user_id
        FROM ignored_users
        WHERE COALESCE(summarized_at, CURRENT_TIMESTAMP + ':coalesced_gap_days DAYS'::INTERVAL) - ':gap_days DAYS'::INTERVAL > CURRENT_TIMESTAMP
        GROUP BY ignored_user_id
        HAVING COUNT(ignored_user_id) >= :threshold
      SQL

      User.where(id: user_ids).find_each { |user| notify_user(user) }
    end

    private

    def notify_user(user)
      params = SystemMessage.new(user).defaults.merge(ignores_threshold: SiteSetting.ignored_users_count_message_threshold)
      title = I18n.t("system_messages.ignored_users_summary.subject_template")
      raw = I18n.t("system_messages.ignored_users_summary.text_body_template", params)

      PostCreator.create(
        Discourse.system_user,
        target_group_names: Group[:moderators].name,
        archetype: Archetype.private_message,
        subtype: TopicSubtype.system_message,
        title: title,
        raw: raw,
        skip_validations: true)
      IgnoredUser.where(ignored_user_id: user.id).update_all(summarized_at: Time.zone.now)
    end
  end
end
