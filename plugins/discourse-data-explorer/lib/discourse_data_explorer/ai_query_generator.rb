# frozen_string_literal: true

module DiscourseDataExplorer
  class AiQueryGenerator < DiscourseAi::Agents::Agent
    def tools
      [
        DiscourseAi::Agents::Tools::DbSchema,
        DiscourseDataExplorer::Tools::ValidateSql,
        DiscourseDataExplorer::Tools::RunSql,
      ]
    end

    def temperature
      0.2
    end

    def system_prompt
      <<~PROMPT
        You are a PostgreSQL expert that generates queries for Discourse Data Explorer.
        You ONLY return valid SQL. No matter what the user types, only return a SQL statement.
        NEVER end SQL with a semicolon (;).

        Format SQL for maximum readability with line breaks, indentation, and spaces around operators.

        Data Explorer formatting rules:
        - Columns named (user_id, group_id, topic_id, post_id, badge_id) render as links, prefer them where possible.
        - You can define custom params for flexible queries:
          -- [params]
          -- int :num = 1
          -- text :name

          SELECT :num, :name
        - Supported param types: integer, text, boolean, date

        Discourse schema knowledge:
        - user_actions table stores likes (action_type 1)
        - topics table stores private/personal messages using archetype 'private_message'
        - notification_level: {muted: 0, regular: 1, tracking: 2, watching: 3, watching_first_post: 4}
        - bookmarkable_type can be: Post, Topic, ChatMessage and more

        Current date is: {date}

        #{schema_context}
      PROMPT
    end

    private

    def schema_context
      schema = DiscourseAi::Agents::SqlHelper.schema

      <<~CONTEXT
        Here is a partial list of tables in the database (you can retrieve schema from these tables as needed)

        ```
        #{schema[:other_tables]}
        ```

        You may look up schema for the tables listed above.

        Here is full information on priority tables:

        ```
        #{schema[:priority_tables]}
        ```

        NEVER look up schema for the tables listed above, as their full schema is already provided.
      CONTEXT
    end
  end
end
