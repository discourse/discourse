# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    class AskAiReportPublisher
      def self.publish(report, result)
        new(report, result).publish
      end

      def initialize(report, result)
        @report = report
        @result = result
      end

      def publish
        raw = [
          I18n.t(
            "discourse_ai.ask_ai_reports.coverage",
            count: @report.reported_ask_count,
            total: @report.total_ask_count,
          ),
          text(@result.fetch("summary")),
        ]
        insights = @result.fetch("insights")
        if insights.empty?
          raw << I18n.t("discourse_ai.ask_ai_reports.no_insights")
        else
          insights.each do |insight|
            raw << "## #{text(insight.fetch("title"))}"
            raw << text(insight.fetch("observation"))
            raw << I18n.t(
              "discourse_ai.ask_ai_reports.suggested_action",
              action: text(insight.fetch("suggested_action")),
            )
            insight
              .fetch("ask_ids")
              .map { |id| @result.fetch("examples").fetch(id) }
              .uniq
              .each { |query| raw << "> #{text(query).gsub("\n", "\n> ")}" }
          end
        end
        raw << "[#{I18n.t("discourse_ai.ask_ai_reports.view_dashboard")}](#{Discourse.base_url}/admin)"
        raw << I18n.t("discourse_ai.ask_ai_reports.disclaimer")
        targets = {}
        unless @report.requested_by_id == Discourse::SYSTEM_USER_ID
          targets[:target_usernames] = @report.requested_by.username
        end
        if @report.send_to_groups?
          group_names =
            Group.where(id: SiteSetting.ai_ask_ai_report_recipient_groups.split("|")).pluck(:name)
          targets[:target_group_names] = group_names.join(",") if group_names.present?
        end
        return if targets.empty?

        PostCreator.create!(
          Discourse.system_user,
          **targets,
          title:
            I18n.t(
              "discourse_ai.ask_ai_reports.title",
              start: @report.start_date.iso8601,
              end: @report.end_date.iso8601,
            ),
          raw: raw.join("\n\n"),
          archetype: Archetype.private_message,
          skip_validations: true,
        )
      end

      private

      def text(value)
        ERB::Util
          .html_escape(value.to_s)
          .gsub(/([\\`*_\[\]{}()#+.!>|~-])/) { |char| "\\#{char}" }
          .gsub("@", "@\u200B")
      end
    end
  end
end
