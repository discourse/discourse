# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    # Computes a digested, significance-gated set of facts about a community for
    # a period. Everything here is deterministic ground truth: the headline
    # metrics (consistent with the admin dashboard tiles) plus richer internal and
    # external signals, each pre-analysed so the LLM only has to phrase them.
    #
    # Returns:
    #   {
    #     period:  { start_date:, end_date:, days: },
    #     trend:   :growing | :steady | :declining | :mixed,
    #     metrics: [ { label:, value:, delta_pct: } ],   # the 4 tile KPIs, always
    #     signals: [ { key:, headline:, score: } ],       # richer facts, gated
    #   }
    class AdminDashboardFacts
      BROWSER_REQ_TYPES = %i[
        page_view_anon_browser
        page_view_anon_browser_mobile
        page_view_logged_in_browser
        page_view_logged_in_browser_mobile
      ].freeze

      MAX_SIGNALS = 6
      MAX_LANDING_TOPIC_DAYS = 93
      MAX_STAFF_RATIO_DAYS = 93

      METRIC_LABELS = {
        new_signups: "new sign-ups",
        dau_mau: "DAU/MAU stickiness (a percentage, not a user count)",
        new_contributors: "new contributors",
        accepted_solutions: "questions resolved (accepted solutions)",
      }.freeze

      def self.compute(start_date:, end_date:)
        new(start_date: start_date, end_date: end_date).compute
      end

      def initialize(start_date:, end_date:)
        @end_date = parse(end_date) || Date.current
        @start_date = parse(start_date) || (@end_date - 30)
        @start_date, @end_date = @end_date, @start_date if @start_date > @end_date

        length = (@end_date - @start_date).to_i
        @period_days = length + 1
        @prev_end = @start_date - 1
        @prev_start = @start_date - (length + 1)
      end

      def compute
        kpis = AdminDashboardHighlights.build(start_date: @start_date, end_date: @end_date)[:kpis]

        signals =
          [
            hot_topic,
            topic_volume,
            unanswered_gap,
            staff_ratio,
            traffic_volume,
            traffic_spike,
            geography,
            landing_topic,
          ].compact.sort_by { |signal| -signal[:score] }.first(MAX_SIGNALS)

        {
          period: {
            start_date: @start_date.to_s,
            end_date: @end_date.to_s,
            days: @period_days,
          },
          trend: trend(kpis),
          metrics: kpis.map { |kpi| metric_for(kpi) },
          signals: signals,
        }
      end

      private

      def parse(value)
        Time.zone.parse(value.to_s)&.to_date
      rescue ArgumentError, TypeError
        nil
      end

      def metric_for(kpi)
        key = kpi[:type]&.to_sym
        label = METRIC_LABELS[kpi[:type]&.to_sym] || kpi[:type].to_s.tr("_", " ")
        {
          key: key,
          category: metric_category(key),
          label: label,
          value: kpi[:value],
          delta_pct: kpi[:percent_change],
        }
      end

      def metric_category(key)
        case key
        when :new_signups
          :acquisition
        when :dau_mau, :new_contributors
          :participation
        when :accepted_solutions
          :support
        end
      end

      def trend(kpis)
        deltas = kpis.map { |kpi| kpi[:percent_change] }.compact
        up = deltas.count { |d| d >= 10 }
        down = deltas.count { |d| d <= -10 }
        return :mixed if up.positive? && down.positive?
        return :growing if up >= 2
        return :declining if down >= 2
        :steady
      end

      def delta_pct(current, previous)
        return nil if previous.blank? || previous.zero?
        (((current - previous).to_f / previous) * 100).round
      end

      def signal(key, headline, score:, category:)
        { key: key, category: category, headline: headline, score: score }
      end

      def topic_category_join(topic_alias: "t", category_alias: "c")
        "LEFT JOIN categories #{category_alias} ON #{category_alias}.id = #{topic_alias}.category_id"
      end

      def topic_conditions(topic_alias: "t", category_alias: "c")
        <<~SQL
          #{topic_alias}.deleted_at IS NULL
          AND #{topic_alias}.visible = true
          AND #{topic_alias}.archetype = 'regular'
          #{category_scope_condition(topic_alias: topic_alias, category_alias: category_alias)}
        SQL
      end

      def category_scope_condition(topic_alias:, category_alias:)
        case SiteSetting.ai_admin_dashboard_highlights_category_scope
        when "all"
          ""
        when "include"
          return "AND 1 = 0" if category_ids_with_subcategories.blank?

          "AND #{topic_alias}.category_id IN (:category_ids)"
        when "include_strict"
          return "AND 1 = 0" if category_ids.blank?

          "AND #{topic_alias}.category_id IN (:category_ids)"
        when "exclude"
          return "" if category_ids_with_subcategories.blank?

          "AND (#{topic_alias}.category_id IS NULL OR #{topic_alias}.category_id NOT IN (:category_ids))"
        when "exclude_strict"
          return "" if category_ids.blank?

          "AND (#{topic_alias}.category_id IS NULL OR #{topic_alias}.category_id NOT IN (:category_ids))"
        else
          "AND (#{topic_alias}.category_id IS NULL OR #{category_alias}.read_restricted = false)"
        end
      end

      def scoped_category_ids
        case SiteSetting.ai_admin_dashboard_highlights_category_scope
        when "include", "exclude"
          category_ids_with_subcategories
        else
          category_ids
        end
      end

      def category_ids
        @category_ids ||=
          SiteSetting
            .ai_admin_dashboard_highlights_categories
            .to_s
            .split("|")
            .filter_map { |category_id| category_id.presence&.to_i }
      end

      def category_ids_with_subcategories
        @category_ids_with_subcategories ||=
          category_ids.flat_map { |category_id| Category.subcategory_ids(category_id) }.uniq
      end

      # ---- internal signals --------------------------------------------------

      def new_topics_count(start_date, end_date)
        DB
          .query_single(
            <<~SQL,
            SELECT COUNT(*)
            FROM topics t
            #{topic_category_join}
            JOIN users u ON u.id = t.user_id
            WHERE t.created_at >= :start_date
              AND t.created_at < (:end_date::date + 1)
              AND #{topic_conditions}
              AND NOT (u.admin OR u.moderator)
          SQL
            start_date: start_date,
            end_date: end_date,
            category_ids: scoped_category_ids,
          )
          .first
          .to_i
      end

      def topic_volume
        current = new_topics_count(@start_date, @end_date)
        previous = new_topics_count(@prev_start, @prev_end)
        delta = delta_pct(current, previous)
        return if delta.nil? || delta.abs < 30
        return if delta.positive? && current < 5
        return if delta.negative? && previous < 5

        direction = delta.positive? ? "up" : "down"
        signal(
          :topic_volume,
          "New topics were #{direction} #{delta.abs}% versus the previous period",
          score: [delta.abs / 200.0, 0.8].min,
          category: :participation,
        )
      end

      def hot_topic
        row =
          DB.query(
            <<~SQL,
            SELECT t.id, t.title, COUNT(p.id) FILTER (WHERE p.post_number > 1) AS replies
            FROM topics t
            #{topic_category_join}
            JOIN posts p ON p.topic_id = t.id AND p.deleted_at IS NULL AND p.post_type = 1
            WHERE t.created_at >= :start_date
              AND t.created_at < (:end_date::date + 1)
              AND #{topic_conditions}
            GROUP BY t.id, t.title
            ORDER BY replies DESC
            LIMIT 1
          SQL
            start_date: @start_date,
            end_date: @end_date,
            category_ids: scoped_category_ids,
          ).first
        return if row.nil? || row.replies.to_i < 10

        avg =
          DB
            .query_single(
              <<~SQL,
            SELECT AVG(reply_count) FROM (
              SELECT COUNT(p.id) FILTER (WHERE p.post_number > 1) AS reply_count
              FROM topics t
              #{topic_category_join}
              JOIN posts p ON p.topic_id = t.id AND p.deleted_at IS NULL AND p.post_type = 1
              WHERE t.created_at >= :start_date AND t.created_at < (:end_date::date + 1)
                AND #{topic_conditions}
              GROUP BY t.id
            ) per_topic
          SQL
              start_date: @start_date,
              end_date: @end_date,
              category_ids: scoped_category_ids,
            )
            .first
            .to_f
        return if avg.positive? && row.replies < (avg * 3)

        signal(
          :hot_topic,
          "Busiest discussion: \"#{row.title}\" with #{row.replies} replies",
          score: 0.7,
          category: :participation,
        )
      end

      def unanswered_gap
        count =
          DB
            .query_single(
              <<~SQL,
            SELECT COUNT(*)
            FROM topics t
            #{topic_category_join}
            JOIN users u ON u.id = t.user_id
            WHERE t.created_at >= :start_date
              AND t.created_at < (:end_date::date + 1)
              AND t.posts_count = 1
              AND #{topic_conditions}
              AND NOT (u.admin OR u.moderator)
          SQL
              start_date: @start_date,
              end_date: @end_date,
              category_ids: scoped_category_ids,
            )
            .first
            .to_i
        return if count < 5

        total = new_topics_count(@start_date, @end_date)
        share = total.positive? ? ((count.to_f / total) * 100).round : 0
        headline = "#{count} new member-created topics received no reply"
        headline = "#{headline} (#{share}% of member-created topics)" if share >= 10

        signal(
          :unanswered_gap,
          headline,
          score: [0.4 + (share / 100.0), 0.9].min,
          category: :support,
        )
      end

      def staff_ratio
        return if @period_days > MAX_STAFF_RATIO_DAYS

        row =
          DB.query(
            <<~SQL,
            SELECT
              COUNT(*) FILTER (WHERE u.admin OR u.moderator) AS staff,
              COUNT(*) AS total
            FROM posts p
            JOIN topics t ON t.id = p.topic_id
            #{topic_category_join}
            JOIN users u ON u.id = p.user_id
            WHERE p.created_at >= :start_date
              AND p.created_at < (:end_date::date + 1)
              AND p.deleted_at IS NULL
              AND p.post_type = 1
              AND u.id > 0
              AND #{topic_conditions}
          SQL
            start_date: @start_date,
            end_date: @end_date,
            category_ids: scoped_category_ids,
          ).first
        return if row.nil? || row.total.to_i < 20

        pct = ((row.staff.to_f / row.total) * 100).round
        return if pct < 40

        signal(
          :staff_ratio,
          "Staff wrote #{pct}% of posts this period",
          score: pct / 100.0,
          category: :participation,
        )
      end

      # ---- external signals --------------------------------------------------

      def daily_browser_pageviews(start_date, end_date)
        req_types = BROWSER_REQ_TYPES.map { |type| ApplicationRequest.req_types[type] }
        DB.query(<<~SQL, req_types: req_types, start_date: start_date, end_date: end_date)
          SELECT date, SUM(count)::int AS count
          FROM application_requests
          WHERE req_type IN (:req_types) AND date >= :start_date AND date <= :end_date
          GROUP BY date
          ORDER BY date ASC
        SQL
      end

      def traffic_volume
        current = daily_browser_pageviews(@start_date, @end_date).sum { |r| r.count }
        previous = daily_browser_pageviews(@prev_start, @prev_end).sum { |r| r.count }
        delta = delta_pct(current, previous)
        return if delta.nil? || delta.abs < 30

        direction = delta.positive? ? "up" : "down"
        signal(
          :traffic_volume,
          "Browser pageviews were #{direction} #{delta.abs}% versus the previous period",
          score: [delta.abs / 200.0, 0.8].min,
          category: :acquisition,
        )
      end

      def traffic_spike
        daily = daily_browser_pageviews(@start_date, @end_date)
        return if daily.size < 3

        counts = daily.map(&:count).sort
        median = counts[counts.size / 2].to_f
        peak = daily.max_by(&:count)
        return if median.zero? || peak.count < (median * 3)

        multiple = (peak.count / median).round(1)
        source = dominant_referrer_for(peak.date)
        headline =
          if source
            "Traffic spiked on #{peak.date} (#{multiple}x the typical day), with #{source} as the top external referrer"
          else
            "Traffic spiked on #{peak.date} (#{multiple}x the typical day)"
          end

        signal(:traffic_spike, headline, score: [multiple / 10.0, 0.95].min, category: :acquisition)
      end

      def dominant_referrer_for(date)
        rows = DB.query(<<~SQL, date: date)
            SELECT normalized_referrer, count
            FROM browser_pageview_referrer_daily_rollups
            WHERE date = :date AND normalized_referrer IS NOT NULL
            ORDER BY count DESC
            LIMIT 5
          SQL
        return if rows.blank?

        total = rows.sum(&:count)
        top = rows.find { |row| external_referrer?(row.normalized_referrer) }
        return if top.nil?
        return if total.zero? || (top.count.to_f / total) < 0.4
        top.normalized_referrer
      end

      def external_referrer?(referrer)
        site_host = BrowserPageviewReferrerInspector.normalize_host(Discourse.current_hostname)
        referrer = referrer.to_s
        return false if referrer.blank? || site_host.blank?

        referrer != site_host && !referrer.start_with?("#{site_host}/") &&
          !referrer.start_with?("#{site_host}?")
      end

      def geography
        current = DB.query(<<~SQL, start_date: @start_date, end_date: @end_date)
            SELECT country_code, SUM(count)::int AS count
            FROM browser_pageview_country_daily_rollups
            WHERE date >= :start_date AND date <= :end_date AND country_code IS NOT NULL
            GROUP BY country_code
            ORDER BY count DESC
            LIMIT 5
          SQL
        return if current.blank?

        total = current.sum(&:count)
        top = current.first
        return if total.zero? || (top.count.to_f / total) < 0.35

        share = ((top.count.to_f / total) * 100).round
        signal(
          :geography,
          "#{share}% of browser pageviews came from #{top.country_code}",
          score: share / 100.0,
          category: :acquisition,
        )
      end

      def landing_topic
        return if @period_days > MAX_LANDING_TOPIC_DAYS

        row =
          DB.query(
            <<~SQL,
            SELECT e.topic_id, t.title, COUNT(*) AS visits
            FROM browser_pageview_events e
            JOIN topics t ON t.id = e.topic_id
            #{topic_category_join}
            WHERE e.created_at >= :start_date
              AND e.created_at < (:end_date::date + 1)
              AND e.topic_id IS NOT NULL
              AND e.normalized_referrer IS NOT NULL
              AND e.source = CASE
                WHEN e.created_at >= :beacon_start_date THEN :source_beacon
                ELSE :source_piggyback
              END
              AND #{topic_conditions}
            GROUP BY e.topic_id, t.title
            ORDER BY visits DESC
            LIMIT 1
          SQL
            start_date: @start_date,
            end_date: @end_date,
            beacon_start_date: BrowserPageviewEvent.beacon_rollup_start_date,
            source_beacon: BrowserPageviewEvent::SOURCE_BEACON,
            source_piggyback: BrowserPageviewEvent::SOURCE_PIGGYBACK,
            category_ids: scoped_category_ids,
          ).first
        return if row.nil? || row.visits.to_i < 50

        signal(
          :landing_topic,
          "External visitors mostly landed on \"#{row.title}\" (#{row.visits} visits)",
          score: 0.6,
          category: :acquisition,
        )
      end
    end
  end
end
