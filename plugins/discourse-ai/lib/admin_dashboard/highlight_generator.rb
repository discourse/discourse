# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    # Builds the AI highlight shown at the top of the admin dashboard.
    # The KPIs are computed server-side (the same numbers the admin dashboard renders),
    # then handed to the admin dashboard highlights agent which explains what changed.
    class HighlightGenerator
      CACHE_TTL = 6.hours
      CACHE_VERSION = 4

      LENSES = {
        acquisition: "Acquisition and discovery",
        participation: "Participation and contribution",
        support: "Support health",
      }.freeze

      def self.generate(start_date:, end_date:, period: nil)
        new(start_date: start_date, end_date: end_date, period: period).generate
      end

      def initialize(start_date:, end_date:, period: nil)
        @start_date = start_date
        @end_date = end_date
        @period = period
      end

      def generate
        return "" if !DiscourseAi::AdminDashboard.highlights_enabled?

        Discourse.cache.fetch(cache_key, expires_in: CACHE_TTL) { generate_highlight }
      end

      private

      attr_reader :start_date, :end_date, :period

      def cache_key
        db = RailsMultisite::ConnectionManagement.current_db
        agent_id = SiteSetting.ai_admin_dashboard_highlights_agent
        "ai_admin_dashboard_highlight:v#{CACHE_VERSION}:#{db}:#{agent_id}:#{categories_cache_key}:#{period}:#{start_date}:#{end_date}:#{I18n.locale}"
      end

      def categories_cache_key
        category_ids =
          SiteSetting
            .ai_admin_dashboard_highlights_categories
            .to_s
            .split("|")
            .filter_map { |category_id| category_id.presence&.to_i }
            .sort
            .join("|")

        "#{SiteSetting.ai_admin_dashboard_highlights_category_scope}:#{category_ids}"
      end

      def generate_highlight
        facts = AdminDashboardFacts.compute(start_date: start_date, end_date: end_date)
        return "" if facts[:metrics].blank?

        agent_instance = admin_dashboard_agent_instance
        return "" if agent_instance.nil?

        bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_instance)
        context =
          DiscourseAi::Agents::BotContext.new(
            user: Discourse.system_user,
            skip_show_thinking: true,
            feature_name: "admin_dashboard_highlights",
            messages: [{ type: :user, content: user_message(facts) }],
          )

        collect_reply(bot, context, agent_instance)
      end

      def admin_dashboard_agent_instance
        DiscourseAi::AdminDashboard.highlights_agent_instance
      end

      def collect_reply(bot, context, agent_instance)
        schema_key = agent_instance.response_format&.first.to_h["key"]
        structured = nil
        streamed = +""

        buffer =
          Proc.new do |partial, _, type|
            if type == :structured_output
              # keep the object; we parse the complete JSON once streaming ends.
              # accumulating incremental string deltas drops spaces before numbers.
              structured = partial
            elsif type.blank? && partial.is_a?(String)
              streamed << partial
            end
          end

        bot.reply(context, &buffer)

        return parse_structured(structured, schema_key) if structured && schema_key.present?
        streamed.strip
      end

      def parse_structured(structured, schema_key)
        raw = structured.to_s
        value = JSON.parse(raw)[schema_key]
        value.to_s.strip
      rescue JSON::ParserError
        DiscourseAi::Utils::BestEffortJsonParser
          .extract_key(raw, :string, schema_key.to_sym)
          .to_s
          .strip
      end

      def user_message(facts)
        <<~MSG.strip
          Community facts for #{facts[:period][:start_date]} to #{facts[:period][:end_date]} — this was a #{facts[:trend]} period.
          Period length: #{facts[:period][:days]} days. Compare only with the previous #{facts[:period][:days]} days.

          Headline metrics (also shown as tiles below the highlight):
          #{facts[:metrics].map { |metric| format_metric(metric) }.join("\n")}

          Community-owner lenses:
          #{format_lenses(facts)}

          Notable this period:
          #{format_signals(facts[:signals])}

          Rules — follow exactly:
          - Use ONLY the numbers and facts listed above. Never state a value that is not listed.
          - Do not mention a metric whose value is "not available".
          - Only mention a traffic source, country, or landing topic if it appears in "Notable" above. Do not invent sources, dates, causes, or numbers.
          - If you mention a traffic source or external referrer, name it exactly as listed or do not mention the source. Never say "a specific external referrer".
          - Do not overstate causality. If the facts only show contrast or correlation, phrase it that way.
          - Do not say traffic "translated", "did not translate", "stemmed", "did not stem", "lifted", or "did not lift" another metric. Do not imply that a traffic spike caused, failed to cause, prevented, or failed to prevent another metric.
          - If you mention a traffic spike, state only its date, size, and listed referrer/source. Put participation or support concerns in a separate sentence.
          - Avoid report phrases like "as evidenced by", "highlighting", "indicating", and "underscoring".
          - If little is notable, say it was a steady period rather than inventing drama.

          Write the admin dashboard highlight: 2 or 3 short, scannable sentences for a community owner. Lead with the trend, then choose the 2-3 most useful next inspection areas from the community-owner lenses. For 7-day ranges, focus on immediate follow-up; for 30-day or longer ranges, focus on sustained patterns. Warm and plain, no hype, no corporate report phrasing, no emoji.#{language_directive}
        MSG
      end

      def language_directive
        locale = I18n.locale.to_s
        return "" if locale.blank? || locale.start_with?("en")
        name = LocaleSiteSetting.language_names.dig(locale, "name") || locale
        " Write the highlight in #{name}."
      end

      def format_metric(metric)
        value = metric[:value].presence || "not available"
        change =
          if metric[:delta_pct].present?
            sign = metric[:delta_pct] >= 0 ? "+" : ""
            " (#{sign}#{metric[:delta_pct]}% versus the previous period)"
          else
            ""
          end
        "- #{metric[:label]}: #{value}#{change}"
      end

      def format_lenses(facts)
        LENSES
          .map do |category, title|
            entries = lens_entries(facts, category)
            next if entries.blank?

            "- #{title}: #{entries.join("; ")}"
          end
          .compact
          .join("\n")
      end

      def lens_entries(facts, category)
        metrics =
          facts[:metrics]
            .select { |metric| metric[:category] == category && metric[:value].present? }
            .map { |metric| format_metric(metric).delete_prefix("- ") }
        signals =
          facts[:signals]
            .select { |signal| signal[:category] == category }
            .map { |signal| signal[:headline] }

        metrics + signals
      end

      def format_signals(signals)
        return "- Nothing else stood out." if signals.blank?
        signals.map { |signal| "- #{signal[:headline]}" }.join("\n")
      end
    end
  end
end
