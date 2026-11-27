# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Agenda
      PAGE_SIZE = 200
      RECURRING_BATCH_SIZE = 100
      MAX_WINDOW = 367.days

      def self.search(user, params)
        new(user, params).search
      end

      def initialize(user, params)
        @params = params
        @after = Finder.time_param(params[:after], :after)&.to_time
        @before = Finder.time_param(params[:before], :before)&.to_time
        if !@after || !@before || @before <= @after || @before - @after > MAX_WINDOW
          raise Discourse::InvalidParameters.new(:before)
        end
        @direction = params.fetch(:direction, "later")
        if !%w[earlier later].include?(@direction)
          raise Discourse::InvalidParameters.new(:direction)
        end
        @anchor =
          Finder.time_param(params[:anchor], :anchor)&.to_time || (later? ? @after : @before)
        raise Discourse::InvalidParameters.new(:anchor) if @anchor < @after || @anchor > @before
        @timezone = Time.find_zone(params[:timezone]) if params[:timezone].present?
        if params[:timezone].present? && !@timezone
          raise Discourse::InvalidParameters.new(:timezone)
        end
        @after_time = civil_time(@after)
        @before_time = civil_time(@before)
        @anchor_time = civil_time(@anchor)
        @cursor_time = Finder.time_param(params[:cursor_time], :cursor_time)&.to_time
        @cursor_id = Integer(params[:cursor_id], exception: false)
        if (params[:cursor_time].present? || params[:cursor_id].present?) &&
             (!@cursor_time || !@cursor_id || @cursor_id < 1)
          raise Discourse::InvalidParameters.new(:cursor_id)
        end
        # Floating and all-day dates can lie outside the viewer's UTC year boundaries.
        @events =
          Finder
            .search(
              user,
              params.merge(after: @after - 2.days, before: @before + 2.days, include_ongoing: true),
            )
            .limit(nil)
            .reorder(nil)
      end

      def search
        single_rsvps =
          Invitee
            .unscoped
            .with_status(:going)
            .where(
              user_id:
                User.where(username_lower: @params[:attending_user].to_s.downcase).select(:id),
              recurring: false,
            )
            .select(:post_id)
        singles = @events.where(recurrence: nil)
        recurring = recurring_scope
        if @params[:attending_user].present?
          singles = singles.or(@events.where(id: single_rsvps))
          recurring = recurring.where.not(id: single_rsvps)
        end

        results = single_occurrences(singles)
        recurring.find_in_batches(batch_size: RECURRING_BATCH_SIZE) do |events|
          streams = [results.each, *events.map { |event| recurring_occurrences(event) }]
          results = merge_page(streams)
        end
        boundary = results.last
        results.reverse! unless later?
        full_page = results.size == PAGE_SIZE
        cursor = { time: boundary[:sort_time].iso8601(6), id: boundary[:event].id } if full_page
        ActiveRecord::Associations::Preloader.new(
          records: results.map { |occurrence| occurrence[:event] }.uniq,
          associations: [:event_dates, { post: { topic: %i[tags category] } }],
        ).call
        {
          occurrences: results,
          next_cursor: cursor,
          has_earlier: later? ? @anchor > @after : full_page,
          has_later: later? ? full_page : @anchor < @before,
        }
      end

      private

      def later?
        @direction == "later"
      end

      def key(occurrence)
        [occurrence[:sort_time], occurrence[:event].id]
      end

      def merge_page(streams)
        candidates = streams.filter_map { |stream| next_candidate(stream) }
        results = []
        PAGE_SIZE.times do |index|
          break if candidates.empty?
          candidate =
            candidates.public_send(later? ? :min_by : :max_by) { |item| key(item[:occurrence]) }
          candidates.delete(candidate)
          results << candidate[:occurrence]
          if index < PAGE_SIZE - 1
            following = next_candidate(candidate[:stream])
            candidates << following if following
          end
        end
        results
      end

      def next_candidate(stream)
        { stream:, occurrence: stream.next }
      rescue StopIteration
        nil
      end

      def single_occurrences(scope)
        aliases =
          ActiveSupport::TimeZone::MAPPING
            .map do |label, name|
              "(#{Event.connection.quote(label)}, #{Event.connection.quote(name)})"
            end
            .join(", ")
        scope =
          scope.joins(
            "LEFT JOIN (VALUES #{aliases}) AS agenda_timezones(label, name) ON timezone = agenda_timezones.label",
          ).group("agenda_timezones.name")
        starts =
          "CASE WHEN recurrence IS NULL THEN original_starts_at ELSE COALESCE(latest_event_dates.starts_at, original_starts_at) END"
        ends =
          "CASE WHEN recurrence IS NULL THEN original_ends_at ELSE COALESCE(latest_event_dates.ends_at, original_ends_at) END"
        sort_time = display_sql(starts)
        end_time = display_sql(ends)
        scope =
          scope.where(
            "#{sort_time} < :before AND (#{sort_time} >= :after OR (recurrence IS NULL AND #{end_time} >= :after))",
            after: @after_time,
            before: @before_time,
          )
        upcoming = "(#{sort_time} >= :anchor OR COALESCE(#{end_time} >= :anchor, FALSE))"
        scope = scope.where(later? ? upcoming : "NOT #{upcoming}", anchor: @anchor_time)
        if @cursor_time
          scope =
            scope.where(
              "(#{sort_time}, discourse_post_event_events.id) #{later? ? ">" : "<"} (?, ?)",
              @cursor_time,
              @cursor_id,
            )
        end
        order = later? ? "ASC" : "DESC"
        scope
          .reorder(Arel.sql("#{sort_time} #{order}, discourse_post_event_events.id #{order}"))
          .limit(PAGE_SIZE)
          .map do |event|
            occurrence(
              event,
              (
                if event.recurring?
                  event[:starts_at] || event.original_starts_at
                else
                  event.original_starts_at
                end
              ),
              event.recurring? ? event[:ends_at] || event.original_ends_at : event.original_ends_at,
            )
          end
      end

      def display_sql(column)
        viewer_time =
          if @timezone
            "(#{column}) AT TIME ZONE 'UTC' AT TIME ZONE #{Event.connection.quote(@timezone.tzinfo.name)}"
          else
            "(#{column}) + INTERVAL '#{@anchor.utc_offset} seconds'"
          end
        "CASE WHEN all_day THEN date_trunc('day', (#{column})) WHEN show_local_time THEN (#{column}) AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(agenda_timezones.name, timezone, 'UTC') ELSE #{viewer_time} END"
      end

      def recurring_scope
        scope = @events.where.not(recurrence: nil)
        bound = @cursor_time || @anchor
        if later?
          # Keep ongoing occurrences and allow for floating dates and implicit end times.
          scope.where(
            "recurrence_until IS NULL OR GREATEST(recurrence_until, original_starts_at) + COALESCE(original_ends_at - original_starts_at, INTERVAL '0') + INTERVAL '2 days' >= ?",
            bound,
          )
        else
          scope.where("original_starts_at <= ?", bound + 2.days)
        end
      end

      def recurring_occurrences(event)
        Enumerator.new do |output|
          after = instant(event, @after_time)
          before = instant(event, @before_time)
          bound = instant(event, @cursor_time || @anchor_time)
          if later?
            duration =
              event.original_ends_at ? event.original_ends_at - event.original_starts_at : 0
            # Civil cursors can fall in a DST gap or repeated hour.
            from = [after, (@cursor_time ? bound : bound - duration) - 1.day].max
            event.each_recurring_occurrence(after: from, before: before) do |date|
              item = occurrence(event, date[:starts_at], date[:ends_at])
              output << item if eligible?(item)
            end
          else
            finish = [before, bound + 1.day].min
            days = 7
            while finish > after
              from = [after, finish - days.days].max
              dates = event.each_recurring_occurrence(after: from, before: finish).to_a
              dates.reverse_each do |date|
                item = occurrence(event, date[:starts_at], date[:ends_at])
                output << item if eligible?(item)
              end
              finish = from
              days = [days * 2, 367].min if dates.empty?
            end
          end
        end
      end

      def eligible?(item)
        upcoming =
          item[:sort_time] >= @anchor_time || (item[:end_time] && item[:end_time] >= @anchor_time)
        return false if later? ? !upcoming : upcoming
        return true unless @cursor_time
        comparison = key(item) <=> [@cursor_time, @cursor_id]
        later? ? comparison > 0 : comparison < 0
      end

      def occurrence(event, starts_at, ends_at)
        {
          event:,
          starts_at:,
          ends_at:,
          sort_time: display_time(event, starts_at),
          end_time: display_time(event, ends_at),
        }
      end

      def civil_time(time)
        Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec + time.subsec)
      end

      def display_time(event, time)
        return unless time
        displayed =
          if event.all_day
            time.utc.beginning_of_day
          elsif event.show_local_time
            time.in_time_zone(event.timezone)
          elsif @timezone
            time.in_time_zone(@timezone)
          else
            time.to_time.getlocal(@anchor.utc_offset)
          end
        civil_time(displayed)
      end

      def instant(event, time)
        return time if event.all_day
        zone = event.show_local_time ? Time.find_zone!(event.timezone || "UTC") : @timezone
        return time - @anchor.utc_offset unless zone
        zone.local(time.year, time.month, time.day, time.hour, time.min, time.sec + time.subsec)
      end
    end
  end
end
