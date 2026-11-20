# frozen_string_literal: true

module Jobs
  class ReportEventRegistrations < ::Jobs::Base
    def execute(args)
      event = DiscourseEvents::Events::Event.find_by(id: args[:event_id])
      return unless event

      event.with_lock do
        topic = event.sync_registration_topic_recipients
        event
          .registrations
          .where(report_post_id: nil)
          .order(:id)
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
