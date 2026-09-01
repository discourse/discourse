# frozen_string_literal: true

module DiscourseAi
  module Agents
    class AskAiQueryRewriter < Agent
      def thinking_effort
        "none"
      end

      def system_prompt
        <<~PROMPT.strip
          Prepare two retrieval queries for a Discourse forum. Do not answer the user's question.

          The input is JSON containing the user's query and the forum's default locale.

          original_query_locale is the locale the final answer must use.
          - Detect it from the user's query when the language is clear.
          - Return an empty string when the language is unclear.
          - Return a Discourse locale identifier, such as en, fr, or zh_CN.

          keyword_query is for Discourse's PostgreSQL-backed keyword search.
          - Keep only two to four essential terms.
          - Do not add synonyms or alternate word forms to the same query.
          - Prefer short, common base terms or stems that work well with prefix matching, such as "admin" instead of "administrator" or "administrate".
          - Correct obvious spelling mistakes and remove connector words and nonessential modifiers.
          - Preserve the user's intent, product names, numbers, quoted text, and explicit Discourse search filters.
          - If the query is not in the forum's default locale, translate it to that locale for the keyword search.
          - Use native Discourse search operators when they express the request exactly. For example, use order:likes for the most-liked topics, l for the latest results, and @username to restrict results to an author.
          - Do not add a text term when an operator-only query expresses the complete request.

          semantic_query is a natural-language description of the information that would answer the user.
          - Preserve the same intent but express it clearly enough for embedding search.
          - Use the forum's default locale so it matches the forum's content.
          - Keep it to one sentence and under twenty words.
          - Return an empty string when the keyword query relies on native search operators for filtering, ordering, or live forum state. Semantic search cannot preserve those constraints.

          The two queries must not broaden, narrow, or reinterpret the user's request.
        PROMPT
      end

      def response_format
        [
          { "key" => "keyword_query", "type" => "string" },
          { "key" => "semantic_query", "type" => "string" },
          { "key" => "original_query_locale", "type" => "string" },
        ]
      end

      def examples
        [
          [
            { query: "怎么删除具备管理员权限的幽灵机器人用户？", forum_default_locale: "en" }.to_json,
            {
              keyword_query: "delete admin bot user",
              semantic_query: "how to remove a bot account that has administrator permissions",
              original_query_locale: "zh_CN",
            }.to_json,
          ],
          [
            {
              query: "What are the 3 most popular topics on the forum?",
              forum_default_locale: "en",
            }.to_json,
            {
              keyword_query: "order:likes",
              semantic_query: "",
              original_query_locale: "en",
            }.to_json,
          ],
          [
            { query: "@nat l logs", forum_default_locale: "en" }.to_json,
            {
              keyword_query: "@nat l logs",
              semantic_query: "",
              original_query_locale: "en",
            }.to_json,
          ],
        ]
      end
    end
  end
end
