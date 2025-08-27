# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)

      build_base_query(guardian, user)
        .then { |query| filter_by_post_id(query, params) }
        .then { |query| filter_by_attending_user(query, params, guardian, user) }
        .then { |query| filter_by_dates(query, params) }
        .then { |query| filter_by_category(query, params) }
        .then { |query| apply_ordering(query) }
        .then { |query| apply_limit(query, params) }
    end

    private

    def self.build_base_query(guardian, user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      DiscoursePostEvent::Event
        .includes(:event_dates, :post, post: :topic)
        .joins(post: :topic)
        .merge(Post.secured(guardian))
        .merge(topics.or(pms))
        .joins(latest_event_date_join)
        .select("discourse_post_event_events.*, latest_event_dates.starts_at")
        .where(
          "(discourse_post_event_events.recurrence IS NOT NULL) OR (latest_event_dates.starts_at IS NOT NULL)",
        )
        .distinct
    end

    def self.latest_event_date_join
      <<~SQL
        LEFT JOIN (
          SELECT DISTINCT ON (event_id)
            event_id,
            starts_at,
            finished_at
          FROM discourse_calendar_post_event_dates
          ORDER BY event_id, finished_at DESC NULLS FIRST, starts_at DESC
        ) latest_event_dates ON latest_event_dates.event_id = discourse_post_event_events.id
      SQL
    end

    def self.filter_by_post_id(events, params)
      return events if params[:post_id].blank?
      events.where(id: params[:post_id])
    end

    def self.filter_by_attending_user(events, params, guardian, user)
      return events if params[:attending_user].blank?

      attending_user = User.find_by(username_lower: params[:attending_user].downcase)
      return events.none if !attending_user

      events =
        events.joins(:invitees).where(
          discourse_post_event_invitees: {
            user_id: attending_user.id,
            status: DiscoursePostEvent::Invitee.statuses[:going],
          },
        )

      guardian.is_admin? ? events : apply_privacy_restrictions(events, user)
    end

    def self.apply_privacy_restrictions(events, user)
      private_status = DiscoursePostEvent::Event.statuses[:private]

      # If no user, can only see non-private events
      return events.where.not(status: private_status) if user.nil?

      events.where(<<~SQL, private_status, private_status, user.id)
  discourse_post_event_events.status != ? OR (
    discourse_post_event_events.status = ? AND EXISTS (
      SELECT 1 FROM discourse_post_event_invitees dpei
      WHERE dpei.post_id = discourse_post_event_events.id
      AND dpei.user_id = ?
    )
  )
SQL
    end

    def self.filter_by_dates(events, params)
      return events if params[:before].blank? && params[:after].blank? && params[:end_date].blank?

      before_date = params[:before]&.to_datetime
      after_date = params[:after]&.to_datetime
      end_date = params[:end_date]&.to_datetime

      # For recurring events
      if before_date || after_date || end_date
        recurring_conditions = []
        recurring_values = []

        if after_date
          # For recurring events: original start date OR recurrence_until should be >= after_date
          # This means either the event starts after the date, or it recurs until after the date
          recurring_conditions << "(discourse_post_event_events.original_starts_at >= ? OR discourse_post_event_events.recurrence_until IS NULL OR discourse_post_event_events.recurrence_until >= ?)"
          recurring_values += [after_date, after_date]
        end

        if before_date
          # For recurring events: original start date should be < before_date
          # We want events that start before the end of our range
          recurring_conditions << "discourse_post_event_events.original_starts_at < ?"
          recurring_values << before_date
        end

        if end_date
          # For recurring events: start date should be before or equal to end_date
          recurring_conditions << "discourse_post_event_events.original_starts_at <= ?"
          recurring_values << end_date
        end

        recurring_condition =
          (
            if recurring_conditions.any?
              "(discourse_post_event_events.recurrence IS NOT NULL AND (#{recurring_conditions.join(" AND ")}))"
            else
              "1=0"
            end
          )

        # For non-recurring events - check event_dates
        non_recurring_conditions = []
        non_recurring_values = []

        if after_date
          non_recurring_conditions << "latest_event_dates.starts_at >= ?"
          non_recurring_values << after_date
        end

        if before_date
          non_recurring_conditions << "latest_event_dates.starts_at < ?"
          non_recurring_values << before_date
        end

        if end_date
          non_recurring_conditions << "latest_event_dates.starts_at <= ?"
          non_recurring_values << end_date
        end

        non_recurring_condition =
          (
            if non_recurring_conditions.any?
              "(discourse_post_event_events.recurrence IS NULL AND (#{non_recurring_conditions.join(" AND ")}))"
            else
              "1=0"
            end
          )

        # Combine both conditions
        full_condition = "(#{recurring_condition}) OR (#{non_recurring_condition})"
        all_values = recurring_values + non_recurring_values

        events.where(full_condition, *all_values)
      else
        events
      end
    end

    def self.filter_by_category(events, params)
      return events if params[:category_id].blank?

      category_id = params[:category_id].to_i
      category_ids =
        (
          if params[:include_subcategories].present?
            Category.subcategory_ids(category_id)
          else
            [category_id]
          end
        )

      events.where(topics: { category_id: category_ids })
    end

    def self.apply_ordering(events)
      events.order("latest_event_dates.starts_at ASC, discourse_post_event_events.id ASC")
    end

    def self.apply_limit(events, params)
      limit = params[:limit]&.to_i || 200
      events.limit(limit.clamp(1, 200))
    end

    def self.listable_topics(guardian)
      Topic.listable_topics.secured(guardian)
    end

    def self.private_messages(user)
      user ? Topic.private_messages_for_user(user) : Topic.none
    end
  end
end
