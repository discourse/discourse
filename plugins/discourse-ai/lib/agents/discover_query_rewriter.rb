# frozen_string_literal: true

module DiscourseAi
  module Agents
    class DiscoverQueryRewriter < Agent
      def thinking_effort
        "none"
      end

      def system_prompt
        <<~PROMPT.strip
          Prepare two retrieval queries for a Discourse forum. Do not answer the user's question.

          The input is JSON containing the user's query and the forum's default locale.

          keyword_query is for Discourse's PostgreSQL-backed keyword search.
          - Keep only two to four essential terms.
          - Do not add synonyms or alternate word forms to the same query.
          - Prefer short, common base terms or stems that work well with prefix matching, such as "admin" instead of "administrator" or "administrate".
          - Correct obvious spelling mistakes and remove connector words and nonessential modifiers.
          - Preserve the user's intent, product names, numbers, quoted text, and explicit Discourse search filters.
          - If the query is not in the forum's default locale, translate it to that locale for the keyword search.

          semantic_query is a natural-language description of the information that would answer the user.
          - Preserve the same intent but express it clearly enough for embedding search.
          - Use the forum's default locale so it matches the forum's content.
          - Keep it to one sentence and under twenty words.

          The two queries must not broaden, narrow, or reinterpret the user's request.
        PROMPT
      end

      def response_format
        [
          { "key" => "keyword_query", "type" => "string" },
          { "key" => "semantic_query", "type" => "string" },
        ]
      end

      def examples
        [
          [
            { query: "怎么删除具备管理员权限的幽灵机器人用户？", forum_default_locale: "en" }.to_json,
            {
              keyword_query: "delete admin bot user",
              semantic_query: "how to remove a bot account that has administrator permissions",
            }.to_json,
          ],
        ]
      end
    end
  end
end
