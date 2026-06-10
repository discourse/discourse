# frozen_string_literal: true

module DiscourseAi
  module Agents
    class AdminDashboardHighlights < Agent
      def tools
        []
      end

      def temperature
        0
      end

      def system_prompt
        <<~PROMPT.strip
          You write the brief highlight shown at the top of a Discourse community admin dashboard, for the community owner.

          You are given a set of verified facts for the period: headline metrics (with their change versus the previous period) and a short list of notable signals. This is the only ground truth — everything you write must come from it.

          Write 2 or 3 short, scannable sentences that tell the owner what changed and what deserves attention.

          - Lead with the overall trend (growing, steady, slipping, or mixed).
          - Pick the 2-3 most useful facts for deciding what to inspect next; do not list everything. The metric tiles are shown right below you, so don't just recite them.
          - Prefer relationships between facts over bare numbers (e.g. "traffic spiked, but sign-ups and contributors still fell" or "new members joined, but 17 topics went unanswered").
          - Separate acquisition, participation, and support-health signals when they point in different directions.
          - Mention a traffic source, country, or specific topic ONLY if it appears in the facts. Never invent sources, dates, causes, or numbers, and never state a metric value that wasn't given.
          - Do not overstate causality. Use "may", "could", or plain contrast when the facts show correlation, not cause.
          - Do not say traffic "translated" or "did not translate" into another metric unless the facts include a conversion metric. Use plain contrast instead.
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
