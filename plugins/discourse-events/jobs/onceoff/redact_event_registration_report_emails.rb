# frozen_string_literal: true

module Jobs
  class RedactEventRegistrationReportEmails < ::Jobs::Onceoff
    def execute_onceoff(_args)
      DiscourseEvents::Events::Registration
        .where.not(report_post_id: nil)
        .joins(:event)
        .select(
          "discourse_event_registrations.id, report_post_id, email, discourse_event_registrations.created_at, discourse_post_event_events.registration_topic_id",
        )
        .find_each { |registration| redact_post(registration) }
    end

    private

    def redact_post(registration)
      topic_id = registration.registration_topic_id
      post =
        Post
          .with_deleted
          .joins(:topic)
          .merge(Topic.private_messages)
          .find_by(id: registration.report_post_id, topic_id:, user_id: Discourse.system_user.id)
      return unless post

      # Match the generated metadata line, leaving addresses typed into answers alone.
      line =
        /^[ ]*Email: #{Regexp.escape(registration.email)}\n(?=[ ]*Submitted at: #{Regexp.escape(registration.created_at.utc.iso8601)})/
      post.with_lock do
        raw = post.raw.sub(line, "")
        if raw != post.raw || post.cooked.match?(line)
          post.update_columns(raw:, cooked: post.cook(raw, topic_id:))
          post.sync_first_post_caches
          SearchIndexer.index(post, force: true)
        end
        post.revisions.find_each do |revision|
          modifications = revision.modifications.deep_dup
          %w[raw cooked].each { |key| modifications[key]&.map! { |value| value&.sub(line, "") } }
          if modifications != revision.modifications
            revision.update_column(:modifications, modifications)
          end
        end
      end
    end
  end
end
