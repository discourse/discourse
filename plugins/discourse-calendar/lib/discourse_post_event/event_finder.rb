# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      dates_join = <<~SQL
      LEFT JOIN (
        SELECT
          finished_at,
          event_id,
          starts_at,
          ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY finished_at DESC NULLS FIRST) as row_num
        FROM discourse_calendar_post_event_dates
      ) dcped ON dcped.event_id = discourse_post_event_events.id AND dcped.row_num = 1

      SQL
      events =
        DiscoursePostEvent::Event
          .select("discourse_post_event_events.*, dcped.starts_at")
          .joins(post: :topic)
          .merge(Post.secured(guardian))
          .merge(topics.or(pms).distinct)
          .joins(dates_join)
          .order("dcped.starts_at ASC")

      include_expired = params[:include_expired].to_s == "true"

      events = events.where("dcped.finished_at IS NULL") unless include_expired

      events = events.where(id: Array(params[:post_id])) if params[:post_id]

      if params[:attending_user].present?
        attending_user = User.find_by(username_lower: params[:attending_user].downcase)
        if attending_user
          events =
            events.joins(:invitees).where(
              discourse_post_event_invitees: {
                user_id: attending_user.id,
                status: DiscoursePostEvent::Invitee.statuses[:going],
              },
            )

          if !guardian.is_admin?
            events =
              events.where(
                "discourse_post_event_events.status != ? OR discourse_post_event_events.status = ? AND EXISTS (
                SELECT 1 FROM discourse_post_event_invitees dpoei
                WHERE dpoei.post_id = discourse_post_event_events.id
                AND dpoei.user_id = ?
              )",
                DiscoursePostEvent::Event.statuses[:private],
                DiscoursePostEvent::Event.statuses[:private],
                user&.id,
              )
          end
        end
      end

      if params[:before].present?
        events = events.where("dcped.starts_at < ?", params[:before].to_datetime)
      end

      if params[:category_id].present?
        if params[:include_subcategories].present?
          events =
            events.where(
              topics: {
                category_id: Category.subcategory_ids(params[:category_id].to_i),
              },
            )
        else
          events = events.where(topics: { category_id: params[:category_id].to_i })
        end
      end

      events = events.limit(params[:limit].to_i) if params[:limit].present?

      events
    end

    private

    def self.listable_topics(guardian)
      Topic.listable_topics.secured(guardian)
    end

    def self.private_messages(user)
      user ? Topic.private_messages_for_user(user) : Topic.none
    end
  end
end
