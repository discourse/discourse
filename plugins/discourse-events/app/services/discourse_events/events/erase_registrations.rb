# frozen_string_literal: true

module DiscourseEvents
  module Events
    class EraseRegistrations
      def self.call(user_id, through: nil)
        registrations = Registration.where(user_id:)
        links = PostCustomField.where(name: Registration::REPORT_USER_FIELD, value: user_id.to_s)
        if through
          registrations = registrations.where(created_at: ..through)
          links = links.where(created_at: ..through)
        end

        Registration.transaction do
          # Wait for any in-flight report to commit its post and registration link.
          report_by_registration = registrations.order(:id).lock.pluck(:id, :report_post_id).to_h
          reports = Post.with_deleted.where(user_id: Discourse.system_user.id)
          reports
            .where(id: report_by_registration.values.compact)
            .or(reports.where(id: links.select(:post_id)))
            .find_each { |post| redact_report(post) }
          registrations.where(id: report_by_registration.keys).delete_all
          links.delete_all
        end
      end

      def self.redact_report(post)
        post.with_lock do
          raw = I18n.t("event_registration.submission_erased", locale: SiteSetting.default_locale)
          now = Time.current
          # Include trashed PMs: their excerpts and search entries could be restored later.
          post.topic = Topic.with_deleted.find_by(id: post.topic_id)
          PostRevision.where(post_id: post.id).delete_all
          post.localizations.destroy_all
          post.update_columns(
            raw:,
            cooked: post.cook(raw, topic_id: post.topic_id),
            version: 1,
            public_version: 1,
            last_version_at: now,
            updated_at: now,
            edit_reason: nil,
          )
          post.sync_first_post_caches
          SearchIndexer.index(post, force: true)
        end
      end
      private_class_method :redact_report
    end
  end
end
