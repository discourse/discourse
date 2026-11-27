# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Event::CreateSuccessorTopic
      include Service::Base

      CONTINUATION_PREFIX_TOPIC_CUSTOM_FIELD = "discourse_post_event_recurring_continuation_prefix"

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

        if author && (author.suspended? || SpamRule::AutoSilence.prevent_posting?(author))
          return false
        end

        true
      end

      # Use the actual Event parser so examples inside code fences do not
      # count as Events introduced by an editor.

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
        context[:original_raw] = post.raw
        context[:rewriter] = BbcodeRewriter.new(
          context[:original_raw],
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
        # Skip missed occurrences when the rollover job runs late.
        next_from = [event_date.starts_at + 1.second, Time.current].max
        context[:next_occurrence] = event.calculate_next_occurrence_from(next_from)
      end

      def archive_occurrence(
        event_date:,
        event:,
        rewriter:,
        original_title:,
        archived_hostnames:,
        original_raw:
      )
        topic.acting_user = Discourse.system_user

        archived_start = format_date(event_date.starts_at)
        archived_end = formatted_end(event_date.ends_at, starts_at: event_date.starts_at)

        archived_raw =
          rewriter.rewrite(
            "start" => archived_start,
            "end" => archived_end,
            "recurrence" => nil,
            "recurrence-until" => nil,
            "recurrenceUntil" => nil,
            "hosts" => archived_hostnames.presence&.join(","),
          )

        # SyncFromPost runs on post_edited. Persist the archived attributes
        # without callbacks so it does not reschedule the completed occurrence
        # or reset RSVPs. Keep the in-memory recurrence for the event-ended
        # workflow. The surrounding service transaction rolls back on failure.
        # Date-only all-day BBCode is parsed at midnight UTC, with an
        # explicit end date parsed at the end of that UTC day. Persist the
        # same values to avoid a post-edit EventDate resync after rollover.
        archived_starts_at =
          event.all_day ? Date.iso8601(archived_start).to_time(:utc) : event_date.starts_at

        archived_ends_at =
          if event.original_ends_at && event_date.ends_at
            event.all_day ? Date.iso8601(archived_end).to_time(:utc).end_of_day : event_date.ends_at
          end

        Event.where(id: event.id).update_all(
          original_starts_at: archived_starts_at,
          original_ends_at: archived_ends_at,
          recurrence: nil,
          recurrence_until: nil,
        )

        post.association(:event).reset
        base_suffix = archived_title_suffix(event_date)
        max_title_attempts = 5

        max_title_attempts.times do |attempt|
          # A failed PostRevisor transaction rolls back persisted changes but
          # may leave the Ruby objects changed. Reload before retrying.
          if attempt.positive?
            post.reload
            post.association(:event).reset
          end

          archive_title =
            topic.title_with_disambiguating_suffix(original_title, base_suffix, attempt:)
          revisor = PostRevisor.new(post)
          post.event_rollover_validation_actor = Discourse.system_user

          begin
            # A failed title revision must not leave a partial post edit
            # inside the surrounding rollover transaction.
            revised = false
            Post.transaction(requires_new: true) do
              revised =
                revisor.revise!(
                  post.user,
                  { raw: archived_raw, title: archive_title },
                  expected_raw: original_raw,
                  bypass_bump: true,
                  bypass_rate_limiter: true,
                  bypass_slow_mode: true,
                  silent: true,
                  skip_post_alert: true,
                )
              raise ActiveRecord::Rollback unless revised
            end
          ensure
            post.event_rollover_validation_actor = nil
          end

          break if revised

          errors = (topic.errors.full_messages + post.errors.full_messages).uniq
          # Do not retry if the revision also failed any unrelated validation.
          details = topic.errors.details
          duplicate_title =
            post.errors.empty? && details.present? &&
              details.all? do |attribute, failures|
                attribute == :base &&
                  failures.all? { |failure| failure[:error] == :topic_title_already_used }
              end

          unless duplicate_title && attempt < max_title_attempts - 1
            raise ActiveRecord::RecordNotSaved.new(errors.to_sentence)
          end
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
            "end" =>
              formatted_end(next_occurrence[:ends_at], starts_at: next_occurrence[:starts_at]),
            "hosts" => successor_hostnames.presence&.join(","),
          )

        # Replace only the previous rollover's generated introduction.
        # Leave any user-authored content untouched.
        previous_prefix = topic.custom_fields[CONTINUATION_PREFIX_TOPIC_CUSTOM_FIELD]
        if previous_prefix.present? && successor_raw.start_with?(previous_prefix)
          successor_raw = successor_raw.delete_prefix(previous_prefix)
        end

        previous_link = "[#{topic.markdown_link_title}](#{post.full_url})"
        continuation_prefix =
          "#{I18n.t("js.post.continue_discussion", postLink: previous_link)}\n\n"

        context[:successor_post] = create_successor_post(
          "#{continuation_prefix}#{successor_raw}",
          original_title,
          recurrence_anchor:,
          continuation_prefix:,
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

      def create_successor_post(raw, title, recurrence_anchor:, continuation_prefix:)
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
              CONTINUATION_PREFIX_TOPIC_CUSTOM_FIELD => continuation_prefix,
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

      def archived_title_suffix(event_date)
        date =
          if event.all_day
            format_date(event_date.starts_at)
          else
            event_date.starts_at.in_time_zone(event.rrule_timezone).strftime("%Y-%m-%d")
          end

        " (archived event on #{date})"
      end

      def formatted_end(value, starts_at:)
        return nil if event.original_ends_at.nil?
        return nil if value.nil?

        if event.all_day
          day_span = event.original_ends_at.utc.to_date - event.original_starts_at.utc.to_date
          return (all_day_date(starts_at) + day_span).iso8601
        end

        format_date(value)
      end

      # All-day BBCode dates are UTC calendar dates, whereas recurrence
      # instants follow the anchor's local wall-clock time. Preserve the
      # anchor's calendar-day offset when daylight saving time changes.
      def all_day_date(value)
        anchor = event.recurrence_anchor_starts_at
        timezone = event.rrule_timezone
        day_offset = anchor.utc.to_date - anchor.in_time_zone(timezone).to_date

        value.in_time_zone(timezone).to_date + day_offset
      end

      def format_date(value)
        return all_day_date(value).iso8601 if event.all_day

        local_time = value.in_time_zone(event.rrule_timezone)
        formatted = local_time.strftime("%Y-%m-%d %H:%M:%S")

        if local_time.usec.positive?
          formatted = "#{formatted}.#{local_time.strftime("%6N")}".sub(/0+\z/, "")
        end

        # Preserve the actual instant when local times repeat at DST fall-back.
        "#{formatted} #{local_time.strftime("%:z")}"
      end
    end
  end
end
