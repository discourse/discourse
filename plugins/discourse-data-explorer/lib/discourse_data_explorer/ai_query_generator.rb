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

    def response_format
      [
        { "key" => "name", "type" => "string" },
        { "key" => "description", "type" => "string" },
        { "key" => "sql", "type" => "string" },
      ]
    end

    def system_prompt
      <<~PROMPT
        You are a PostgreSQL expert that generates queries for Discourse Data Explorer.

        Always verify your query works by testing it with RunSql. If it returns an error, fix the query and test again.

        Return a JSON response with three fields:
        - "name": a short descriptive name for the query (under 60 characters)
        - "description": a one-sentence description of what the query does
        - "sql": the SQL query

        ## Data Explorer SQL rules
        - NEVER end SQL with a semicolon (;)
        - Format SQL for maximum readability with line breaks, indentation, and spaces around operators

        ## Data Explorer rendering
        Columns with these exact names render as clickable links: user_id, group_id, topic_id, post_id, badge_id, category_id
        Always alias ID columns to these names (e.g. SELECT t.id AS topic_id), never use bare "id".

        ## Available parameters
        -- [params]
        -- int             :int = 3
        -- bigint          :bigint = 12345678912345
        -- boolean         :boolean
        -- null boolean    :boolean_three = #null
        -- string          :string = little bunny foo foo
        -- date            :date = 14 jul 2015
        -- time            :time = 5:02 pm
        -- datetime        :datetime = 14 jul 2015 5:02 pm
        -- double          :double = 3.1415
        -- string          :inet = 127.0.0.1/8
        -- user_id         :user_id = system
        -- post_id         :post_id = http://localhost:3000/t/adsfdsfajadsdafdsds-sf-awerjkldfdwe/21/1?u=system
        -- topic_id        :topic_id = /t/-/21
        -- int_list        :int_list = 1,2,3
        -- string_list     :string_list = a,b,c
        -- category_id     :category_id = meta
        -- group_id        :group_id = admins
        -- user_list       :mul_users = system,discobot
        -- current_user_id :me
        Supported types: integer, text, boolean, date, current_user_id (auto-injected)
        Prefix with "null" for optional params: -- null int :user
        NEVER use :: to cast params (conflicts with :param syntax). Use CAST(:param AS type) instead.

        ## Discourse domain knowledge
        - topics.archetype: 'regular' = normal topics, 'private_message' = PMs/messages. When users say "messages" or "PMs", filter by archetype = 'private_message'. Default to 'regular' for "topics".
        - Always filter deleted content: t.deleted_at IS NULL AND p.deleted_at IS NULL
        - posts.post_number: 1 = opening post, > 1 = replies
        - posts.post_type: 1 = regular, 2 = moderator_action, 3 = small_action, 4 = whisper (staff-only, exclude from public counts)
        - users.staged = true are placeholder users from emails — exclude from user counts unless specifically asked
        - Exclude system user with: user_id > 0
        - user_actions.action_type: 1 = like, 2 = was_liked, 3 = bookmark, 4 = new_topic, 5 = reply, 7 = mention
        - post_actions.post_action_type_id: 2 = like, 3 = off_topic, 4 = inappropriate, 8 = spam
        - notification_level (in topic_users, category_users): 0 = muted, 1 = regular, 2 = tracking, 3 = watching
        - bookmarks: bookmarkable_type can be 'Post', 'Topic', 'ChatMessage'
        - user_stats has aggregated counts: topic_count, post_count, likes_given, likes_received, days_visited, time_read

        Current date is: #{Date.today.strftime("%B %d, %Y")}
      PROMPT
    end
  end
end
