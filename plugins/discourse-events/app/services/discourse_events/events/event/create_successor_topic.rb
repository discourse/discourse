# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Event::CreateSuccessorTopic
      include Service::Base

      params do
        attribute :event_date_id, :integer
        validates :event_date_id, presence: true
      end

      model :event_date
      model :event
      policy :rollover_allowed

      try do
        step :prepare_rollover

        transaction do
          step :archive_occurrence
          step :create_successor
          step :copy_successor_invitees
        end
      end

      def self.rollover_allowed?(event)
        source_post = event.post
        source_topic = source_post&.topic
        author = source_post&.user

        return false if source_post.nil? || source_topic.nil? || author.nil?

        # The system Guardian must not publish successor topics attributed to
        # inactive or staged accounts.
        return false if !author.active? || author.staged?

        return false if source_topic.archetype != Archetype.default
        return false if source_post.hidden? || source_post.deleted_at.present?
        return false if !source_topic.visible? || source_topic.deleted_at.present?

        # A delegated human content edit must not be republished under
        # the original author's identity. Trusted system revisions and
        # metadata-only edits do not introduce that authorship risk.
        non_owner_content_edit =
          source_post
            .post_revisions
            .where.not(user_id: [source_post.user_id, Discourse::SYSTEM_USER_ID])
            .any? { |revision| revision.modifications.key?("raw") }

        return false if non_owner_content_edit

        # When the most recent editor is another human, require a
        # recorded metadata-only revision. Fail closed if their edit
        # lacks revision history rather than assuming it was harmless.
        last_editor_id = source_post.last_editor_id

        if last_editor_id != source_post.user_id && last_editor_id != Discourse::SYSTEM_USER_ID
          latest_revision = source_post.post_revisions.order(number: :desc).first

          if latest_revision.nil? || latest_revision.user_id != last_editor_id ||
               latest_revision.modifications.key?("raw")
            return false
          end
        end

        if author && (author.suspended? || SpamRule::AutoSilence.prevent_posting?(author))
          return false
        end

        true
      end

      private

      def fetch_event_date(params:)
        EventDate.find_by(id: params.event_date_id)
      end

      def fetch_event(event_date:)
        event_date.event
      end

      def rollover_allowed(event:)
        self.class.rollover_allowed?(event)
      end

      def prepare_rollover(event_date:, event:)
        context[:original_title] = topic.title
        original_raw = post.raw
        context[:rewriter] = BbcodeRewriter.new(
          original_raw,
          tag: "event",
          selector: "div.discourse-post-event",
          cook_options: {
            topic_id: post.topic_id,
            user_id: post.user_id,
          },
        )
        # Archived host references must resolve against their persisted
        # identities, not usernames that may have been renamed or deleted.
        # Suspended hosts remain linked to the historical Event.
        context[:archived_hostnames] = event.hosts.map(&:username)
        # A successor is a new Event and must independently validate hosts.
        context[:successor_hostnames] = eligible_successor_hostnames
        context[:invitees] = snapshot_invitees
        context[:successor_post] = nil
        context[:recurrence_anchor] = event.recurrence_anchor_starts_at
        context[:next_occurrence] = event.calculate_next_occurrence_from(
          event_date.starts_at + 1.second,
        )
      end

      def archive_occurrence(event_date:, event:, rewriter:, original_title:, archived_hostnames:)
        topic.acting_user = Discourse.system_user

        archived_raw =
          rewriter.rewrite(
            "start" => format_date(event_date.starts_at),
            "end" => formatted_end(event_date.ends_at),
            "recurrence" => nil,
            "recurrence-until" => nil,
            "recurrenceUntil" => nil,
            "hosts" => archived_hostnames.presence&.join(","),
          )

        # SyncFromPost runs on post_edited. Persist the archived attributes
        # without callbacks so it does not reschedule the completed occurrence
        # or reset RSVPs. Keep the in-memory recurrence for the event-ended
        # workflow. The surrounding service transaction rolls back on failure.
        Event.where(id: event.id).update_all(
          original_starts_at: event_date.starts_at,
          original_ends_at: event.original_ends_at ? event_date.ends_at : nil,
          recurrence: nil,
          recurrence_until: nil,
        )

        post.association(:event).reset
        revisor = PostRevisor.new(post)
        post.event_rollover_validation_actor = Discourse.system_user

        begin
          revised =
            revisor.revise!(
              post.user,
              { raw: archived_raw, title: archived_title(original_title) },
              bypass_bump: true,
              bypass_rate_limiter: true,
              bypass_slow_mode: true,
              silent: true,
              skip_post_alert: true,
            )
        ensure
          post.event_rollover_validation_actor = nil
        end

        unless revised
          errors = (topic.errors.full_messages + post.errors.full_messages).uniq
          raise ActiveRecord::RecordNotSaved.new(errors.to_sentence)
        end
      end

      def create_successor(
        rewriter:,
        next_occurrence:,
        original_title:,
        recurrence_anchor:,
        successor_hostnames:
      )
        return if next_occurrence.nil?

        successor_raw =
          rewriter.rewrite(
            "start" => format_date(next_occurrence[:starts_at]),
            "end" => formatted_end(next_occurrence[:ends_at]),
            "hosts" => successor_hostnames.presence&.join(","),
          )

        context[:successor_post] = create_successor_post(
          successor_raw,
          original_title,
          recurrence_anchor:,
        )
        context[:successor_topic] = context[:successor_post].topic
      end

      def copy_successor_invitees(invitees:, successor_post:)
        return if successor_post.nil?

        copy_recurring_invitees(invitees, successor_post)
      end

      def event_date
        context[:event_date]
      end

      def event
        context[:event]
      end

      def post
        event.post
      end

      def topic
        post.topic
      end

      def create_successor_post(raw, title, recurrence_anchor:)
        PostCreator.create!(
          post.user,
          acting_user: Discourse.system_user,
          guardian: Discourse.system_user.guardian,
          title:,
          raw:,
          category: topic.category_id,
          tags: topic.tags.pluck(:name),
          topic_opts: {
            custom_fields: {
              Event::RECURRENCE_ANCHOR_TOPIC_CUSTOM_FIELD => recurrence_anchor.iso8601,
              Event::RECURRENCE_ANCHOR_INITIALIZING_TOPIC_CUSTOM_FIELD => true,
            },
          },
        ).reload
      end

      # An existing Event may retain a host who has subsequently become
      # ineligible. A successor is a new Event, so it must only inherit hosts
      # meeting the current new-host validation requirements.
      def eligible_successor_hostnames
        category = topic.category
        event.hosts.filter_map do |host|
          next if !host.active? || host.suspended? || host.staged?
          next if category && !host.guardian.can_see_category?(category)

          host.username
        end
      end

      def snapshot_invitees
        Invitee
          .unscoped
          .where(post_id: event.id)
          .pluck(:user_id, :status, :recurring, :notified)
          .map do |user_id, status, recurring, notified|
            { user_id:, status:, recurring:, notified: }
          end
      end

      def copy_recurring_invitees(invitees, successor_post)
        successor_event = successor_post.event
        going = Invitee.statuses[:going]

        invitees
          .select { |invitee| invitee[:status] == going && invitee[:recurring] }
          .each do |invitee|
            successor_invitee =
              Invitee.create!(
                post_id: successor_event.id,
                user_id: invitee[:user_id],
                status: going,
                recurring: true,
                notified: invitee[:notified],
              )

            successor_invitee.update_topic_tracking!
          end
      end

      def archived_title(original_title)
        date =
          if event.all_day
            event_date.starts_at.utc.strftime("%Y-%m-%d")
          else
            event_date.starts_at.in_time_zone(event.rrule_timezone).strftime("%Y-%m-%d")
          end

        suffix = " — #{date}"
        candidate = title_with_suffix(original_title, suffix)
        return candidate unless archived_title_taken?(candidate)

        suffix = " — #{date} ##{topic.id}"
        candidate = title_with_suffix(original_title, suffix)
        return candidate unless archived_title_taken?(candidate)

        counter = 2

        loop do
          suffix = " — #{date} ##{topic.id}-#{counter}"
          candidate = title_with_suffix(original_title, suffix)
          return candidate unless archived_title_taken?(candidate)

          counter += 1
        end
      end

      def title_with_suffix(original_title, suffix)
        max_length = SiteSetting.max_topic_title_length
        return suffix[-max_length, max_length] if suffix.length >= max_length

        title_length = max_length - suffix.length
        "#{original_title.truncate(title_length, omission: "").rstrip}#{suffix}"
      end

      def archived_title_taken?(candidate)
        return false if SiteSetting.duplicate_topic_titles.allowed?

        topic
          .duplicate_title_candidates
          .where.not(id: topic.id)
          .where("lower(title) = ?", candidate.downcase)
          .exists?
      end

      def formatted_end(value)
        return nil if event.original_ends_at.nil?
        return nil if value.nil?

        format_date(value)
      end

      def format_date(value)
        if event.all_day
          value.utc.strftime("%Y-%m-%d")
        else
          value.in_time_zone(event.rrule_timezone).strftime("%Y-%m-%d %H:%M")
        end
      end
    end
  end
end
