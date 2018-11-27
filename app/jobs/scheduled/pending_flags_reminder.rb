require_dependency 'flag_query'

module Jobs

  class PendingFlagsReminder < Jobs::Scheduled

    every 1.hour

    def execute(args)
      if SiteSetting.notify_about_flags_after > 0

        flagged_posts_count = PostAction.flagged_posts_count

        return unless flagged_posts_count > 0

        flag_ids = pending_flag_ids

        if flag_ids.size > 0 && last_notified_id.to_i < flag_ids.max

          usernames = active_moderator_usernames
          mentions = usernames.size > 0 ? "@#{usernames.join(', @')} " : ""

          PostCreator.create(
            Discourse.system_user,
            target_group_names: Group[:moderators].name,
            archetype: Archetype.private_message,
            subtype: TopicSubtype.system_message,
            title: I18n.t('flags_reminder.subject_template', count: flagged_posts_count),
            raw: mentions + I18n.t('flags_reminder.flags_were_submitted', count: SiteSetting.notify_about_flags_after, base_path: Discourse.base_path)
          )

          self.last_notified_id = flag_ids.max
        end
      end
    end

    def pending_flag_ids
      FlagQuery.flagged_post_actions(filter: 'active')
        .where('post_actions.created_at < ?', SiteSetting.notify_about_flags_after.to_i.hours.ago)
        .pluck(:id)
    end

    def last_notified_id
      $redis.get(self.class.last_notified_key)&.to_i
    end

    def last_notified_id=(arg)
      $redis.set(self.class.last_notified_key, arg)
    end

    def self.last_notified_key
      "last_notified_pending_flag_id".freeze
    end

    def active_moderator_usernames
      User.where(moderator: true)
        .human_users
        .order('last_seen_at DESC')
        .limit(3)
        .pluck(:username)
    end

  end

end
