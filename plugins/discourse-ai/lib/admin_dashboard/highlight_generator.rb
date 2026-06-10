# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    # Builds the AI highlight shown at the top of the admin dashboard.
    # The KPIs are computed server-side (the same numbers the admin dashboard renders),
    # then handed to the admin dashboard highlights agent which explains what changed.
    class HighlightGenerator
      CACHE_TTL = 6.hours
      CACHE_VERSION = 3

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
        "ai_admin_dashboard_highlight:v#{CACHE_VERSION}:#{db}:#{agent_id}:#{period}:#{start_date}:#{end_date}:#{I18n.locale}"
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

          Headline metrics (also shown as tiles below the highlight):
          #{facts[:metrics].map { |metric| format_metric(metric) }.join("\n")}

          Notable this period:
          #{format_signals(facts[:signals])}

          Rules — follow exactly:
          - Use ONLY the numbers and facts listed above. Never state a value that is not listed.
          - Only mention a traffic source, country, or landing topic if it appears in "Notable" above. Do not invent sources, dates, causes, or numbers.
          - Do not overstate causality. If the facts only show contrast or correlation, phrase it that way.
          - Do not say traffic "translated" or "did not translate" into another metric unless the facts include a conversion metric. Use plain contrast instead.
          - Avoid report phrases like "as evidenced by", "highlighting", "indicating", and "underscoring".
          - If little is notable, say it was a steady period rather than inventing drama.

          Write the admin dashboard highlight: 2 or 3 short, scannable sentences for a community owner. Lead with the trend, pick the 2-3 facts most useful for deciding what to inspect next, and prefer relationships between metrics. Warm and plain, no hype, no corporate report phrasing, no emoji.#{language_directive}
        MSG
      end

      def language_directive
        locale = I18n.locale.to_s
        return "" if locale.blank? || locale.start_with?("en")
        name = LocaleSiteSetting.language_names.dig(locale, "name") || locale
        " Write the highlight in #{name}."
      end

      def format_metric(metric)
        change =
          if metric[:delta_pct].present?
            sign = metric[:delta_pct] >= 0 ? "+" : ""
            " (#{sign}#{metric[:delta_pct]}% versus the previous period)"
          else
            ""
          end
        "- #{metric[:label]}: #{metric[:value]}#{change}"
      end

      def format_signals(signals)
        return "- Nothing else stood out." if signals.blank?
        signals.map { |signal| "- #{signal[:headline]}" }.join("\n")
      end
    end
  end
end
