# frozen_string_literal: true

module Jobs
  class RetryEventRegistrationReports < ::Jobs::Scheduled
    every 10.minutes

    def execute(_args)
      return unless SiteSetting.discourse_events_enabled && SiteSetting.discourse_post_event_enabled

      pending = DiscourseEvents::Events::Registration.unreported.where(created_at: ..5.minutes.ago)
      DiscourseEvents::Events::Event
        .visible
        .joins(post: :topic)
        .where(id: pending.select(:event_id))
        .select(:id)
        .find_each { |event| Jobs.enqueue(:report_event_registrations, event_id: event.id) }
    end
  end
end
