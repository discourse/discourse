# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::DeleteExpiredEventPosts < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled

      delay = SiteSetting.delete_expired_event_posts_after
      return if delay < 0

      calendar_topic_ids =
        Post
          .joins(:_custom_fields)
          .where(post_custom_fields: { name: DiscourseCalendar::CALENDAR_CUSTOM_FIELD })
          .pluck(:topic_id)

      post_events =
        CalendarEvent
          .joins(:post, :topic)
          .where(topic_id: calendar_topic_ids)
          .where("TRIM(COALESCE(calendar_events.recurrence, '')) = ''")
          .where("NOT topics.closed AND NOT topics.archived")

      event_post_ids = post_events.pluck(:post_id).to_set

      post_events.each do |event|
        end_date = event.end_date.presence || event.start_date + 24.hours
        next if end_date + delay.hour > Time.current

        # get all the replies to the post
        reply_ids = event.post.reply_ids(system_guardian)
        replies = Post.where(id: reply_ids.map { |r| r[:id] })

        # only delete replies that have no event
        replies.each { |reply| destroy_post(reply) if !event_post_ids.include?(reply.id) }

        # delete the post
        destroy_post(event.post)
      end
    end

    def destroy_post(post)
      PostDestroyer.new(
        Discourse.system_user,
        post,
        context: I18n.t("discourse_calendar.event_expired"),
      ).destroy
    end

    def system_guardian
      @system_guardian ||= Guardian.new(Discourse.system_user)
    end
  end
end
