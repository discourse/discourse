require_dependency 'flag_query'

module Jobs

  class PendingFlagsReminder < Jobs::Scheduled

    every 1.day

    def execute(args)
      if SiteSetting.notify_about_flags_after > 0 &&
         PostAction.flagged_posts_count > 0 &&
         FlagQuery.flagged_post_actions('active').where('post_actions.created_at < ?', SiteSetting.notify_about_flags_after.to_i.hours.ago).pluck(:id).count > 0

        PostCreator.create(
          Discourse.system_user,
          target_group_names: ["staff"],
          archetype: Archetype.private_message,
          subtype: TopicSubtype.system_message,
          title: I18n.t('flags_reminder.subject_template', { count: PostAction.flagged_posts_count }),
          raw: I18n.t('flags_reminder.flags_were_submitted', { count: SiteSetting.notify_about_flags_after })
        )
      end
    end

  end

end
