require_dependency 'admin_user_index_query'

module Jobs

  class PendingUsersReminder < Jobs::Scheduled
    every 9.hours

    def execute(args)
      if SiteSetting.must_approve_users
        count = AdminUserIndexQuery.new({query: 'pending'}).find_users_query.count
        if count > 0
          target_usernames = Group[:moderators].users.map do |u|
            u.id > 0 && u.notifications.joins(:topic)
                                       .where("notifications.id > ?", u.seen_notification_id)
                                       .where("notifications.read = false")
                                       .where("topics.subtype = '#{TopicSubtype.pending_users_reminder}'")
                                       .count == 0 ? u.username : nil
          end.compact

          unless target_usernames.empty?
            PostCreator.create(
              Discourse.system_user,
              target_usernames: target_usernames,
              archetype: Archetype.private_message,
              subtype: TopicSubtype.pending_users_reminder,
              title: I18n.t("system_messages.pending_users_reminder.subject_template", {count: count}),
              raw: I18n.t("system_messages.pending_users_reminder.text_body_template", {count: count, base_url: Discourse.base_url})
            )
          end
        end
      end
    end

  end

end
