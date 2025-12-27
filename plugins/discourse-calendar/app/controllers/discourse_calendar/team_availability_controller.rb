# frozen_string_literal: true

module DiscourseCalendar
  class TeamAvailabilityController < DiscourseCalendarController
    requires_login

    EVENT_TYPES = %w[
      leave
      sick
      family-reasons
      work
      public-holiday
      authorized-absence
      special-leave
      parental-leave
    ].freeze

    def index
      respond_to do |format|
        format.html
        format.json do
          topic_id = SiteSetting.holiday_calendar_topic_id.to_i
          return render json: { error: "no_topic_configured" } if topic_id == 0

          topic = Topic.find_by(id: topic_id)
          guardian.ensure_can_see!(topic) if topic
          return render json: { error: "topic_not_found" } if topic.nil?

          group = nil
          if params[:group_name].present?
            group = Group.find_by(name: params[:group_name])
            return render json: { error: "group_not_found" } if group.nil?
            guardian.ensure_can_see!(group)
          end

          start_date = parse_date(params[:start_date]) || Time.current.beginning_of_week(:monday)
          end_date = parse_date(params[:end_date]) || (start_date + 14.days)

          events_by_member = build_events_by_member(topic_id, start_date, end_date)
          members = fetch_members(group, events_by_member.keys)
          user_groups = current_user.groups.order(:name)

          render json: {
                   members:
                     members.map do |u|
                       {
                         id: u.id,
                         username: u.username,
                         name: u.name,
                         avatar_template: u.avatar_template,
                         timezone: u.user_option&.timezone,
                       }
                     end,
                   events_by_member:,
                   groups:
                     user_groups.map { |g| { id: g.id, name: g.name, full_name: g.full_name } },
                 }
        end
      end
    end

    private

    def fetch_members(group, user_ids_with_events)
      if group
        group
          .users
          .where(active: true)
          .where.not(id: Discourse::SYSTEM_USER_ID)
          .includes(:user_option)
          .order(:username)
      else
        User
          .where(id: user_ids_with_events, active: true)
          .where.not(id: Discourse::SYSTEM_USER_ID)
          .includes(:user_option)
          .order(:username)
      end
    end

    def build_events_by_member(topic_id, start_date, end_date)
      events_by_member = Hash.new { |h, k| h[k] = [] }

      fetch_standalone_events(topic_id, start_date, end_date).each do |event|
        events_by_member[event[:user_id]] << event
      end

      fetch_public_holidays(topic_id, start_date, end_date).each do |event|
        events_by_member[event[:user_id]] << event
      end

      events_by_member
    end

    def fetch_standalone_events(topic_id, start_date, end_date)
      DB
        .query(<<~SQL, topic_id:, start_date:, end_date:)
          SELECT post_number, description, start_date, end_date, user_id
          FROM calendar_events
          WHERE topic_id = :topic_id
            AND post_id IS NOT NULL
            AND start_date <= :end_date
            AND (end_date >= :start_date OR end_date IS NULL)
        SQL
        .map do |row|
          {
            type: detect_event_type(row.description),
            message: row.description,
            from: row.start_date,
            to: row.end_date,
            user_id: row.user_id,
            post_url: Post.url("-", topic_id, row.post_number),
          }
        end
    end

    def fetch_public_holidays(topic_id, start_date, end_date)
      DB
        .query(<<~SQL, topic_id:, start_date:, end_date:)
          SELECT start_date, user_id, description
          FROM calendar_events
          WHERE topic_id = :topic_id
            AND post_id IS NULL
            AND start_date >= :start_date
            AND start_date <= :end_date
        SQL
        .map do |row|
          {
            type: "public-holiday",
            message: row.description,
            from: row.start_date,
            to: nil,
            user_id: row.user_id,
          }
        end
    end

    def detect_event_type(message)
      return "default" if message.blank?

      match = message.match(/#([\w-]+)/)
      return "default" unless match

      tag = match[1].downcase
      tag = tag.split("(").first if tag.include?("(")

      EVENT_TYPES.include?(tag) ? tag : "default"
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end
end
