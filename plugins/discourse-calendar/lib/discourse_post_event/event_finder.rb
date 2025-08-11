# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)

      build_base_query(guardian, user)
        .then { |query| apply_filters(query, params, guardian, user) }
        .then { |query| apply_date_filters(query, params) }
        .then { |query| apply_category_filters(query, params) }
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
        .where("latest_event_dates.starts_at IS NOT NULL")
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

    def self.apply_filters(events, params, guardian, user)
      events
        .then { |query| filter_by_expiration(query, params) }
        .then { |query| filter_by_post_id(query, params) }
        .then { |query| filter_by_attending_user(query, params, guardian, user) }
    end

    def self.filter_by_expiration(events, params)
      return events if params[:include_expired].to_s == "true"
      events.where("latest_event_dates.finished_at IS NULL")
    end

    def self.filter_by_post_id(events, params)
      return events if params[:post_id].blank?
      events.where(id: params[:post_id])
    end

    def self.filter_by_attending_user(events, params, guardian, user)
      return events if params[:attending_user].blank?

      attending_user = User.find_by(username_lower: params[:attending_user].downcase)
      return events if !attending_user

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

      events
        .where.not(status: private_status)
        .or(
          events
            .where(status: private_status)
            .joins(:invitees)
            .where(discourse_post_event_invitees: { user_id: user&.id }),
        )
    end

    def self.apply_date_filters(events, params)
      events
        .then { |query| apply_before_date_filter(query, params) }
        .then { |query| apply_start_date_filter(query, params) }
        .then { |query| apply_end_date_filter(query, params) }
    end

    def self.apply_before_date_filter(events, params)
      return events if params[:before].blank?

      before_date = params[:before].to_datetime
      events.where(
        "latest_event_dates.starts_at < ? OR " \
          "(discourse_post_event_events.recurrence IS NOT NULL AND " \
          "discourse_post_event_events.original_starts_at < ? AND " \
          "(discourse_post_event_events.recurrence_until IS NULL OR " \
          "discourse_post_event_events.recurrence_until >= ?))",
        before_date,
        before_date,
        before_date,
      )
    end

    def self.apply_start_date_filter(events, params)
      return events if params[:start_date].blank?

      start_date = params[:start_date].to_datetime
      events.where(
        "latest_event_dates.starts_at >= ? OR " \
          "(discourse_post_event_events.recurrence IS NOT NULL AND " \
          "(discourse_post_event_events.recurrence_until IS NULL OR " \
          "discourse_post_event_events.recurrence_until >= ?))",
        start_date,
        start_date,
      )
    end

    def self.apply_end_date_filter(events, params)
      return events if params[:end_date].blank?

      end_date = params[:end_date].to_datetime
      events.where(
        "latest_event_dates.starts_at <= ? OR " \
          "(discourse_post_event_events.recurrence IS NOT NULL AND " \
          "discourse_post_event_events.original_starts_at <= ?)",
        end_date,
        end_date,
      )
    end

    def self.apply_category_filters(events, params)
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

      events.joins(post: :topic).where(topics: { category_id: category_ids })
    end

    def self.apply_limit(events, params)
      return events if params[:limit].blank?
      events.limit(params[:limit].to_i)
    end

    def self.listable_topics(guardian)
      Topic.listable_topics.secured(guardian)
    end

    def self.private_messages(user)
      user ? Topic.private_messages_for_user(user) : Topic.none
    end
  end
end
