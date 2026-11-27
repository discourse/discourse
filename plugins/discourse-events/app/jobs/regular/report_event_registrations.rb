# frozen_string_literal: true

module Jobs
  class ReportEventRegistrations < ::Jobs::Base
    def execute(args)
      DiscourseEvents::Events::Event.transaction do
        event =
          DiscourseEvents::Events::Event
            .visible
            .joins(post: :topic)
            .lock("FOR UPDATE OF discourse_post_event_events")
            .find_by(id: args[:event_id])
        next unless event
        topic = event.sync_registration_topic_recipients
        event
          .registrations
          .unreported
          .order(:id)
          .lock
          .each do |submission|
            params = { raw: submission.report_body, skip_validations: true }
            if topic
              params[:topic_id] = topic.id
            else
              params.merge!(
                archetype: Archetype.private_message,
                target_usernames:
                  User.where(id: event.registration_host_ids).pluck(:username).join(","),
                title: I18n.t("event_registration.report_title", event: event.post.topic.title),
              )
            end
            post = PostCreator.create!(Discourse.system_user, params)
            PostCustomField.create!(
              post_id: post.id,
              name: DiscourseEvents::Events::Registration::REPORT_USER_FIELD,
              value: submission.user_id.to_s,
              created_at: submission.created_at,
            )
            unless topic
              topic = post.topic
              event.update_column(:registration_topic_id, topic.id)
            end
            submission.update_column(:report_post_id, post.id)
          end
      end
    end
  end
end
