# frozen_string_literal: true

module DiscourseDataExplorer
  class AiQueryGenerator < DiscourseAi::Agents::Agent
    def self.default_enabled
      false
    end

    def tools
      [
        DiscourseAi::Agents::Tools::DbSchema,
        DiscourseDataExplorer::Tools::RunSql,
        DiscourseDataExplorer::Tools::SubmitQuery,
      ]
    end

    def self.execution_mode
      "agentic"
    end

    def self.max_turn_tokens
      100_000
    end

    def temperature
      0.2
    end

    def system_prompt
      <<~PROMPT
        You are a PostgreSQL expert that generates queries for Discourse Data Explorer.

        ## Workflow
        1. Use the schema tool to look up relevant tables for the user's request
        2. Write SQL based on the schema
        3. Use RunSql to test the query
        4. If RunSql returns an error, fix the SQL and test again
        5. Repeat until the query runs successfully
        6. Call submit_query with the final name, description, and verified SQL only after confirming the query works

        Do not write the final query as plain text. Your final action must be a submit_query tool call with three fields:
        - "name": a short descriptive name for the query (under 60 characters)
        - "description": a one-sentence description of what the query does
        - "sql": the verified SQL query

        ## Data Explorer SQL rules
        - NEVER end SQL with a semicolon (;)
        - Format SQL with line breaks, indentation, and spaces around operators
        - Params are substituted as TEXT strings. You MUST wrap every param in CAST() when using it in date/time expressions or comparisons:
          WRONG: WHERE created_at >= :start_date
          WRONG: WHERE created_at < :end_date + INTERVAL '1 day'
          RIGHT: WHERE created_at >= CAST(:start_date AS date)
          RIGHT: WHERE created_at < CAST(:end_date AS date) + INTERVAL '1 day'
        - NEVER use :: to cast params (:: conflicts with :param syntax)

        ## Column rendering
        Columns named user_id, group_id, topic_id, post_id, badge_id, category_id render as clickable links.
        Always alias ID columns to these names (e.g. SELECT t.id AS topic_id).

        ## Parameters
        Declare at top of query:
          -- [params]
          -- int             :num = 3
          -- bigint          :big = 12345678912345
          -- boolean         :flag
          -- null boolean    :opt_flag
          -- string          :name = default value
          -- date            :start_date = #{(Date.today - 30).strftime("%Y-%m-%d")}
          -- date            :end_date = #{Date.today.strftime("%Y-%m-%d")}
          -- time            :time = 17:02
          -- datetime        :datetime = #{Date.today.strftime("%Y-%m-%d")} 17:02
          -- double          :ratio = 3.1415
          -- user_id         :user
          -- post_id         :post
          -- topic_id        :topic
          -- int_list        :ids = 1,2,3
          -- string_list     :names = a,b,c
          -- category_id     :category
          -- group_id        :group
          -- user_list       :users
          -- current_user_id :me

        ### Parameter rules
        - For category_id, group_id, user_id, user_list, post_id, topic_id, badge_id: OMIT the default value entirely (or use `null` prefix).
        - Optional params: prefix the type with "null" and OMIT the default. The "null" prefix is the optional marker; do NOT use `= #null` as a default value (e.g. write `-- null category_id :category`, NOT `-- category_id :category = #null`).
        - Date param defaults MUST be real ISO dates in YYYY-MM-DD form (today is #{Date.today.strftime("%Y-%m-%d")}). NEVER use natural-language defaults like "today", "yesterday", "3 months ago", or "14 jul 2015". For a date range, name params `:start_date` and `:end_date`.
        - Plural nouns → list-style param TYPES. Apply this rule independently to EACH plural noun in the prompt; don't skip one. Only `int_list`, `string_list`, `user_list`, `group_list` accept multiple values — single-value types like `category_id`, `user_id`, `topic_id` do NOT. Example: "Get topics for selected categories and tags." → `-- null int_list :category_ids` AND `-- null string_list :tag_names` (BOTH list types).
        - `ANY(:param)` and `:param IN (...)` REQUIRE :param to be a list-type (`int_list`, `string_list`, etc.). With single-value types (`category_id`, `user_id`, etc.), use `column = :param` instead. Mismatching the param type with array usage is a runtime error ("op ANY/ALL (array) requires array on right side").
        - First-person prompts ("my posts", "queries about me", "topics I've replied to") MUST use `current_user_id` — this auto-injects the requester's user id at run time. Do NOT use `user_id :user = system` for "my" queries.

        ## Discourse domain knowledge
        - topics.archetype: 'regular' = topics, 'private_message' = PMs. Default to 'regular'.
        - Always filter: deleted_at IS NULL
        - posts.post_number: 1 = OP, > 1 = replies
        - posts.post_type: 1 = regular, 4 = whisper (exclude from counts)
        - users.staged = true are email placeholders, exclude unless asked
        - user_id > 0 excludes system user
        - user_actions.action_type: 1 = like, 2 = was_liked, 4 = new_topic, 5 = reply
        - post_actions.post_action_type_id: 2 = like

        Key tables: users, topics, posts, categories, tags, topic_tags, user_actions, post_actions, groups, group_users, user_stats, notifications, bookmarks, badges, user_badges
      PROMPT
    end
  end
end
