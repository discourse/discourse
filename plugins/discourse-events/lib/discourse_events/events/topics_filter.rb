# frozen_string_literal: true

module DiscourseEvents
  module Events
    class TopicsFilter
      STATES = %w[any upcoming ongoing past].freeze
      DATE_REGEXP = /\A[12]\d{3}-(0?[1-9]|1[0-2])-(0?[1-9]|[12]\d|3[01])\z/

      STARTS_AT_SQL =
        "COALESCE(current_event_dates.starts_at, discourse_post_event_events.original_starts_at)"
      # Mirrors Event#ongoing?: an event without an end runs until the end of its start day.
      ENDS_AT_SQL =
        "COALESCE(current_event_dates.ends_at, date_trunc('day', #{STARTS_AT_SQL}) + INTERVAL '1 day')"

      STATE_CONDITIONS = {
        "upcoming" =>
          "NOT discourse_post_event_events.closed AND current_event_dates.finished_at IS NULL AND #{STARTS_AT_SQL} > :now",
        "ongoing" =>
          "NOT discourse_post_event_events.closed AND current_event_dates.finished_at IS NULL AND #{STARTS_AT_SQL} <= :now AND #{ENDS_AT_SQL} > :now",
        "past" =>
          "discourse_post_event_events.closed OR current_event_dates.finished_at IS NOT NULL OR #{ENDS_AT_SQL} <= :now",
      }.freeze

      class << self
        def register(plugin)
          plugin.add_filter_custom_filter("event") do |scope, values, _guardian|
            filter_by_state(scope, values) if enabled?
          end

          plugin.add_filter_custom_filter("event-after") do |scope, values, _guardian|
            filter_by_start(scope, ">=", values) if enabled?
          end

          plugin.add_filter_custom_filter("event-before") do |scope, values, _guardian|
            filter_by_start(scope, "<", values) if enabled?
          end

          plugin.add_filter_custom_filter("event-attending") do |scope, values, guardian|
            filter_by_attendee(scope, values, guardian) if enabled?
          end

          plugin.add_filter_custom_filter("order:event-start") do |scope, direction, _guardian|
            order_by_start(scope, direction) if enabled?
          end

          plugin.register_modifier(:topics_filter_options) do |results, _guardian|
            results.concat(options) if enabled?
            results
          end
        end

        def filter_by_state(scope, values)
          states = values.flat_map { |value| value.split(",") }.map(&:strip) & STATES
          return if states.empty?
          return scope.where(id: topic_events.select("posts.topic_id")) if states.include?("any")

          condition = states.map { |state| "(#{STATE_CONDITIONS[state]})" }.join(" OR ")
          scope.where(id: topic_events.where(condition, now: Time.current).select("posts.topic_id"))
        end

        def filter_by_start(scope, operator, values)
          value = values.last.to_s
          return if !value.match?(DATE_REGEXP)

          date = Time.zone.parse(value)
          return if date.nil?

          scope.where(
            id: topic_events.where("#{STARTS_AT_SQL} #{operator} ?", date).select("posts.topic_id"),
          )
        end

        def filter_by_attendee(scope, values, guardian)
          names =
            values
              .flat_map { |value| value.split(",") }
              .map { |name| name.strip.delete_prefix("@").downcase }
              .compact_blank
          return if names.empty?

          user_ids = User.where(username_lower: names - ["me"]).pluck(:id)
          user_ids << guardian.user.id if names.include?("me") && guardian.authenticated?
          return scope.none if user_ids.empty?

          events =
            Event
              .visible
              .joins(:invitees)
              .where(
                discourse_post_event_invitees: {
                  user_id: user_ids,
                  status: Invitee.statuses[:going],
                },
              )
          events = Finder.apply_privacy_restrictions(events, guardian.user) if !guardian.is_admin?

          scope.where(
            id: events.joins(:post).where(posts: { post_number: 1 }).select("posts.topic_id"),
          )
        end

        def order_by_start(scope, direction)
          direction = direction == "ASC" ? "ASC" : "DESC"
          starts =
            topic_events.where("posts.topic_id = topics.id").select("#{STARTS_AT_SQL} AS starts_at")

          scope.joins("LEFT JOIN LATERAL (#{starts.to_sql}) topic_event_starts ON true").order(
            "topic_event_starts.starts_at #{direction} NULLS LAST",
          )
        end

        def options
          [
            {
              name: "event:",
              description: I18n.t("discourse_post_event.filter.description.event"),
              priority: 1,
              delimiters: [
                {
                  name: ",",
                  description: I18n.t("discourse_post_event.filter.description.event_any_of"),
                },
              ],
              prefixes: [
                {
                  name: "-",
                  description: I18n.t("discourse_post_event.filter.description.exclude_event"),
                },
              ],
            },
            *STATES.map do |state|
              {
                name: "event:#{state}",
                description: I18n.t("discourse_post_event.filter.description.event_#{state}"),
              }
            end,
            {
              name: "event-after:",
              description: I18n.t("discourse_post_event.filter.description.event_after"),
            },
            {
              name: "event-before:",
              description: I18n.t("discourse_post_event.filter.description.event_before"),
            },
            {
              name: "event-attending:",
              description: I18n.t("discourse_post_event.filter.description.event_attending"),
              type: "username",
              extra_entries: [
                {
                  name: "me",
                  description: I18n.t("discourse_post_event.filter.description.event_attending_me"),
                },
              ],
            },
            {
              name: "order:event-start",
              description: I18n.t("discourse_post_event.filter.description.order_event_start"),
            },
            {
              name: "order:event-start-asc",
              description: I18n.t("discourse_post_event.filter.description.order_event_start_asc"),
            },
          ]
        end

        private

        def enabled?
          SiteSetting.discourse_post_event_enabled
        end

        # Events can only live in a topic's first post, so each matches at most one topic.
        def topic_events
          Event.visible.joins(:post).where(posts: { post_number: 1, deleted_at: nil }).joins(<<~SQL)
            LEFT JOIN LATERAL (
              SELECT starts_at, ends_at, finished_at
              FROM discourse_calendar_post_event_dates
              WHERE event_id = discourse_post_event_events.id
              ORDER BY #{EventDate.current_ordering_sql}
              LIMIT 1
            ) current_event_dates ON true
          SQL
        end
      end
    end
  end
end
