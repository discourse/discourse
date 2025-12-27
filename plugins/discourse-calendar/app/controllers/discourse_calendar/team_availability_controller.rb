# frozen_string_literal: true

module DiscourseCalendar
  class TeamAvailabilityController < DiscourseCalendarController
    requires_login

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

          start_date = Time.current.beginning_of_week(:monday)
          end_date = start_date + 14.days

          events = fetch_events(topic_id, start_date, end_date)
          user_ids = events.flat_map { |e| [e[:user_id], *e[:user_ids]] }.compact.uniq

          if group
            group_user_ids = group.users.pluck(:id)
            user_ids = user_ids & group_user_ids
          end

          members =
            User
              .where(id: user_ids, active: true)
              .where.not(id: Discourse::SYSTEM_USER_ID)
              .includes(:user_option)
              .order(:username)

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
                   events: events,
                   groups:
                     user_groups.map do |g| { id: g.id, name: g.name, full_name: g.full_name } end,
                 }
        end
      end
    end

    private

    def fetch_events(topic_id, start_date, end_date)
      events = []

      DB
        .query(<<~SQL, topic_id: topic_id, start_date: start_date, end_date: end_date)
        SELECT post_number, description, start_date, end_date, user_id
        FROM calendar_events
        WHERE topic_id = :topic_id AND post_id IS NOT NULL
          AND start_date <= :end_date AND (end_date >= :start_date OR end_date IS NULL)
      SQL
        .each do |row|
          events << {
            type: "standalone",
            message: row.description,
            from: row.start_date,
            to: row.end_date,
            user_id: row.user_id,
            post_url: Post.url("-", topic_id, row.post_number),
          }
        end

      grouped = {}

      DB
        .query(<<~SQL, topic_id: topic_id, start_date: start_date, end_date: end_date)
        SELECT region, start_date, user_id, description
        FROM calendar_events
        WHERE topic_id = :topic_id AND post_id IS NULL
          AND start_date >= :start_date AND start_date <= :end_date
      SQL
        .each do |row|
          key = "#{row.region&.split("_")&.first}-#{row.start_date.strftime("%Y-%j")}"
          grouped[key] ||= { type: "grouped", from: row.start_date, messages: [], user_ids: [] }
          grouped[key][:messages] << row.description
          grouped[key][:user_ids] << row.user_id
        end

      grouped.each_value do |v|
        v[:message] = v.delete(:messages).uniq.sort.join(", ")
        v[:user_ids].uniq!
      end

      events + grouped.values
    end
  end
end
