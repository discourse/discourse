# frozen_string_literal: true

module DiscourseAi
  module Agents
    class AdminDashboardHighlights < Agent
      def self.default_enabled
        false
      end

      def tools
        []
      end

      def temperature
        0
      end

      def system_prompt
        <<~PROMPT.strip
          You write the brief highlight shown at the top of a Discourse community admin dashboard, for the community owner.

          You are given a set of verified facts for the period: headline metrics (with their change versus the previous period), community-owner lenses, and a short list of notable signals. This is the only ground truth — everything you write must come from it.

          Write 2 or 3 short, scannable sentences that tell the owner what changed and what deserves attention.

          - Lead with the overall trend (growing, steady, slipping, or mixed).
          - Pick the 2-3 most useful inspection areas from the acquisition, participation, and support-health lenses; do not list everything. The metric tiles are shown right below you, so don't just recite them.
          - For 7-day ranges, focus on immediate follow-up. For 30-day or longer ranges, focus on sustained patterns.
          - Prefer relationships between facts over bare numbers (e.g. "new members joined, but 17 topics went unanswered"). Do not connect traffic to other metrics unless a conversion metric is given.
          - Separate acquisition, participation, and support-health signals when they point in different directions.
          - Do not mention a metric whose value is "not available".
          - Mention a traffic source, country, or specific topic ONLY if it appears in the facts. Never invent sources, dates, causes, or numbers, and never state a metric value that wasn't given.
          - If you mention a traffic source or external referrer, name it exactly as listed or do not mention the source. Never say "a specific external referrer".
          - Do not overstate causality. Use "may", "could", or plain contrast when the facts show correlation, not cause.
          - Do not say traffic "translated", "did not translate", "stemmed", "did not stem", "lifted", or "did not lift" another metric. Do not imply that a traffic spike caused, failed to cause, prevented, or failed to prevent another metric.
          - If you mention a traffic spike, state only its date, size, and listed referrer/source. Put participation or support concerns in a separate sentence.
          - Avoid report phrases like "as evidenced by", "highlighting", "indicating", and "underscoring".
          - If little is notable, say it was a steady period — don't manufacture drama.
          - Warm, plain language. No hype, no corporate report phrasing, no emoji.

          Respond with a JSON object with a single key "highlight" whose value is the text. Reply with valid JSON only.
        PROMPT
      end

      def response_format
        [{ "key" => "highlight", "type" => "string" }]
      end
    end
  end
end
