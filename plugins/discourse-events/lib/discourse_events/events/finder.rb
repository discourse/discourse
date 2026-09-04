# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Finder
      class << self
        def search(user, params = {})
          guardian = Guardian.new(user)

          build_base_query(guardian, user, params)
            .then { |query| filter_by_post_id(query, params) }
            .then { |query| filter_by_topic_id(query, params) }
            .then { |query| filter_by_attending_user(query, params, guardian, user) }
            .then { |query| filter_by_dates(query, params) }
            .then { |query| filter_by_category(query, params) }
            .then { |query| filter_by_tags(query, params, guardian) }
            .then { |query| filter_by_search(query, params) }
            .then { |query| filter_by_status(query, params) }
            .then { |query| filter_by_format(query, params) }
            .then { |query| apply_ordering(query, params) }
            .then { |query| apply_limit(query, params) }
        end

        def time_param(value, name)
          return if value.blank?
          return Time.current if value == "now"

          value.to_datetime
        rescue ArgumentError, Date::Error
          raise Discourse::InvalidParameters.new(name)
        end

        def limit_param(value)
          return if value.blank?

          limit = Integer(value, exception: false)
          raise Discourse::InvalidParameters.new(:limit) if limit.nil? || limit < 1

          [limit, 200].min
        end

        public

        def build_base_query(guardian, user, params)
          topics = listable_topics(guardian)
          pms = private_messages(user)

          scope = DiscourseEvents::Events::Event.visible
          scope = scope.open if params[:include_closed].blank?

          scope
            .joins(post: :topic)
            .merge(Post.secured(guardian))
            .merge(topics.or(pms))
            .joins(latest_event_date_join)
            .select(
              "discourse_post_event_events.*, latest_event_dates.starts_at, latest_event_dates.ends_at, latest_event_dates.finished_at",
            )
            .where(
              "(discourse_post_event_events.recurrence IS NOT NULL) OR (latest_event_dates.starts_at IS NOT NULL) OR (discourse_post_event_events.original_starts_at IS NOT NULL)",
            )
            .group(
              "discourse_post_event_events.id, latest_event_dates.starts_at, latest_event_dates.ends_at, latest_event_dates.finished_at",
            )
        end

        def latest_event_date_join
          <<~SQL
        LEFT JOIN (
          SELECT DISTINCT ON (event_id)
            event_id,
            starts_at,
            ends_at,
            finished_at
          FROM discourse_calendar_post_event_dates
          ORDER BY event_id, #{DiscourseEvents::Events::EventDate.current_ordering_sql}
        ) latest_event_dates ON latest_event_dates.event_id = discourse_post_event_events.id
      SQL
        end

        def filter_by_post_id(events, params)
          return events if params[:post_id].blank?
          events.where(id: params[:post_id])
        end

        def filter_by_topic_id(events, params)
          return events if params[:topic_id].blank?
          events.where(topics: { id: params[:topic_id] })
        end

        def filter_by_attending_user(events, params, guardian, user)
          return events if params[:attending_user].blank?

          attending_user = User.find_by(username_lower: params[:attending_user].downcase)
          return events.none if !attending_user

          statuses = [DiscourseEvents::Events::Invitee.statuses[:going]]
          if params[:include_interested].present? &&
               can_include_interested?(guardian, user, attending_user)
            statuses << DiscourseEvents::Events::Invitee.statuses[:interested]
          end

          events =
            events.joins(:invitees).where(
              discourse_post_event_invitees: {
                user_id: attending_user.id,
                status: statuses,
              },
            )

          guardian.is_admin? ? events : apply_privacy_restrictions(events, user)
        end

        def can_include_interested?(guardian, user, attending_user)
          guardian.is_admin? || user&.id == attending_user.id
        end

        def apply_privacy_restrictions(events, user)
          private_status = DiscourseEvents::Events::Event.statuses[:private]

          # If no user, can only see non-private events
          return events.where.not(status: private_status) if user.nil?

          # User can see private events if they still belong to an invited group.
          events.where(<<~SQL, private_status, private_status, user.id)
          discourse_post_event_events.status != ?
          OR (
            discourse_post_event_events.status = ?
            AND EXISTS (
              SELECT 1
              FROM group_users
              INNER JOIN groups ON groups.id = group_users.group_id
              WHERE group_users.user_id = ?
                AND groups.name = ANY(discourse_post_event_events.raw_invitees)
            )
          )
        SQL
        end

        def filter_by_dates(events, params)
          return events if params[:before].blank? && params[:after].blank?

          before_date = time_param(params[:before], :before)
          after_date = time_param(params[:after], :after)
          include_ongoing = params[:include_ongoing].present?

          recurring_scope = build_recurring_date_scope(after_date, before_date)
          non_recurring_scope =
            build_non_recurring_date_scope(after_date, before_date, include_ongoing:)

          # Apply the combined scope using OR logic
          events.merge(recurring_scope.or(non_recurring_scope))
        end

        public

        def build_recurring_date_scope(after_date, before_date)
          scope = DiscourseEvents::Events::Event.where.not(recurrence: nil)

          if after_date
            # For recurring events: original start date OR recurrence_until should be >= after_date
            scope =
              scope.where(
                "original_starts_at >= ? OR recurrence_until IS NULL OR recurrence_until >= ?",
                after_date,
                after_date,
              )
          end

          if before_date
            # For recurring events: original start date should be < before_date
            scope = scope.where("original_starts_at < ?", before_date)
          end

          scope
        end

        def build_non_recurring_date_scope(after_date, before_date, include_ongoing: false)
          scope = DiscourseEvents::Events::Event.where(recurrence: nil)
          if after_date
            if include_ongoing
              scope =
                scope.where(
                  "latest_event_dates.starts_at >= ? OR (latest_event_dates.ends_at IS NOT NULL AND latest_event_dates.ends_at >= ?)",
                  after_date,
                  after_date,
                )
            else
              scope = scope.where("latest_event_dates.starts_at >= ?", after_date)
            end
          end
          scope = scope.where("latest_event_dates.starts_at < ?", before_date) if before_date
          scope
        end

        def filter_by_category(events, params)
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

        def filter_by_tags(events, params, guardian)
          tag_names =
            Array(params[:tags])
              .flat_map { |tag| tag.to_s.split(",") }
              .filter_map { |tag| tag.strip.downcase.presence }
              .uniq
          return events if tag_names.empty?

          tags = DiscourseTagging.visible_tags(guardian).where(name: tag_names)
          return events.none unless tags.count == tag_names.length

          matching_topic_ids =
            TopicTag
              .where(tag_id: tags.select(:id))
              .group(:topic_id)
              .having("COUNT(DISTINCT tag_id) = ?", tag_names.length)
              .select(:topic_id)

          events.where(topics: { id: matching_topic_ids })
        end

        def filter_by_search(events, params)
          search = params[:search].to_s.strip[0, 100]
          return events if search.blank?

          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
          events.where(
            "discourse_post_event_events.name ILIKE :pattern OR " \
              "discourse_post_event_events.description ILIKE :pattern OR " \
              "discourse_post_event_events.location ILIKE :pattern",
            pattern:,
          )
        end

        def filter_by_status(events, params)
          statuses =
            Array(params[:status])
              .flat_map { |status| status.to_s.split(",") }
              .filter_map { |status| Event.statuses[status.to_sym] }
              .uniq
          return events if params[:status].blank?
          return events.none if statuses.empty?

          events.where(status: statuses)
        end

        def filter_by_format(events, params)
          case params[:event_format]
          when nil, ""
            events
          when "virtual"
            events.where.not(url: nil).where(location: [nil, ""])
          when "in_person"
            events.where(url: [nil, ""]).where.not(location: nil).where.not(location: "")
          when "hybrid"
            events.where.not(url: [nil, ""]).where.not(location: [nil, ""])
          else
            events.none
          end
        end

        def apply_ordering(events, params)
          order_direction = params[:order] == "desc" ? "DESC" : "ASC"
          events.order(
            "latest_event_dates.starts_at #{order_direction}, discourse_post_event_events.id #{order_direction}",
          )
        end

        def apply_limit(events, params)
          events.limit(limit_param(params[:limit]) || 200)
        end

        def listable_topics(guardian)
          topics = Topic.listable_topics.secured(guardian)
          topics = topics.visible unless guardian.can_see_unlisted_topics?
          topics
        end

        def private_messages(user)
          user ? Topic.private_messages_for_user(user) : Topic.none
        end
      end

      private

      private
    end
  end
end
