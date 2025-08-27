# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Researcher < Tool
        attr_reader :filter, :result_count, :goals, :dry_run

        class << self
          def signature
            {
              name: name,
              description:
                "Analyze and extract information from content across the forum based on specified filters",
              parameters: [
                { name: "filter", description: filter_description, type: "string" },
                {
                  name: "goals",
                  description:
                    "The specific information you want to extract or analyze from the filtered content, you may specify multiple goals",
                  type: "string",
                },
                {
                  name: "dry_run",
                  description: "When true, only count matching posts without processing data",
                  type: "boolean",
                },
              ],
            }
          end

          def filter_description
            <<~TEXT
              Filter string to target specific content. Space-separated filters use AND logic, OR creates separate filter groups.

              **Filters:**
              - username:user1 or usernames:user1,user2 - posts by specific users
              - group:group1 or groups:group1,group2 - posts by users in specific groups
              - post_type:first|reply - first posts only or replies only
              - keywords:word1,word2 - full-text search in post content
              - topic_keywords:word1,word2 - full-text search in topics (returns all posts from matching topics)
              - topic:123 or topics:123,456 - specific topics by ID
              - category:name1 or categories:name1,name2 - posts in categories (by name/slug)
              - tag:tag1 or tags:tag1,tag2 - posts in topics with tags
              - after:YYYY-MM-DD, before:YYYY-MM-DD - filter by post creation date
              - topic_after:YYYY-MM-DD, topic_before:YYYY-MM-DD - filter by topic creation date
              - status:open|closed|archived|noreplies|single_user - topic status filters
              - max_results:N - limit results (per OR group)
              - order:latest|oldest|latest_topic|oldest_topic|likes - sort order
              #{assign_tip}

              **OR Logic:** Each OR group processes independently - filters don't cross boundaries.

              Examples:
              - 'username:sam after:2023-01-01' - sam's posts after date
              - 'max_results:50 category:bugs OR tag:urgent' - (≤50 bug posts) OR (all urgent posts)
            TEXT
          end

          def assign_tip
            if SiteSetting.respond_to?(:assign_enabled) && SiteSetting.assign_enabled
              (<<~TEXT).strip
                assigned_to:username or assigned_to:username1,username2 - topics assigned to a specific user
                assigned_to:* - topics assigned to any user
                assigned_to:nobody - topics not assigned to any user
              TEXT
            end
          end

          def name
            "researcher"
          end

          def accepted_options
            [
              option(:researcher_llm, type: :llm),
              option(:max_results, type: :integer),
              option(:include_private, type: :boolean),
              option(:max_tokens_per_post, type: :integer),
              option(:max_tokens_per_batch, type: :integer),
            ]
          end
        end

        def invoke(&blk)
          max_results = options[:max_results] || 1000

          @filter = parameters[:filter] || ""
          @goals = parameters[:goals] || ""
          @dry_run = parameters[:dry_run].nil? ? false : parameters[:dry_run]

          post = Post.find_by(id: context.post_id)
          goals = parameters[:goals] || ""
          dry_run = parameters[:dry_run].nil? ? false : parameters[:dry_run]

          return { error: "No goals provided" } if goals.blank?
          return { error: "No filter provided" } if @filter.blank?

          guardian = nil
          guardian = Guardian.new(context.user) if options[:include_private]

          filter =
            DiscourseAi::Utils::Research::Filter.new(
              @filter,
              limit: max_results,
              guardian: guardian,
            )

          if filter.invalid_filters.present?
            return(
              {
                error:
                  "Invalid filter fragment: #{filter.invalid_filters.join(" ")}\n\n#{self.class.filter_description}",
              }
            )
          end

          @result_count = filter.search.count

          blk.call details

          if dry_run
            { dry_run: true, goals: goals, filter: @filter, number_of_posts: @result_count }
          else
            process_filter(filter, goals, post, &blk)
          end
        rescue StandardError => e
          { error: "Error processing research: #{e.message}" }
        end

        def details
          if @dry_run
            I18n.t("discourse_ai.ai_bot.tool_description.researcher_dry_run", description_args)
          else
            I18n.t("discourse_ai.ai_bot.tool_description.researcher", description_args)
          end
        end

        def summary
          if @dry_run
            I18n.t("discourse_ai.ai_bot.tool_summary.researcher_dry_run")
          else
            I18n.t("discourse_ai.ai_bot.tool_summary.researcher")
          end
        end

        def description_args
          { count: @result_count || 0, filter: @filter || "", goals: @goals || "" }
        end

        protected

        MIN_TOKENS_FOR_RESEARCH = 8000
        MIN_TOKENS_FOR_POST = 50

        def process_filter(filter, goals, post, &blk)
          if researcher_llm.max_prompt_tokens < MIN_TOKENS_FOR_RESEARCH
            raise ArgumentError,
                  "LLM max tokens too low for research. Minimum is #{MIN_TOKENS_FOR_RESEARCH}."
          end

          max_tokens_per_batch = options[:max_tokens_per_batch].to_i
          if max_tokens_per_batch <= MIN_TOKENS_FOR_RESEARCH
            max_tokens_per_batch = researcher_llm.max_prompt_tokens - 2000
          end

          max_tokens_per_post = options[:max_tokens_per_post]
          if max_tokens_per_post.nil?
            max_tokens_per_post = 2000
          elsif max_tokens_per_post < MIN_TOKENS_FOR_POST
            max_tokens_per_post = MIN_TOKENS_FOR_POST
          end

          formatter =
            DiscourseAi::Utils::Research::LlmFormatter.new(
              filter,
              max_tokens_per_batch: max_tokens_per_batch,
              tokenizer: researcher_llm.tokenizer,
              max_tokens_per_post: max_tokens_per_post,
            )

          results = []

          formatter.each_chunk { |chunk| results << run_inference(chunk[:text], goals, post, &blk) }

          if context.cancel_manager&.cancelled?
            {
              dry_run: false,
              goals: goals,
              filter: @filter,
              results: "Cancelled by user",
              cancelled_by_user: true,
            }
          else
            { dry_run: false, goals: goals, filter: @filter, results: results }
          end
        end

        def researcher_llm
          @researcher_llm ||=
            (
              options[:researcher_llm].present? &&
                LlmModel.find_by(id: options[:researcher_llm].to_i)&.to_llm
            ) || self.llm
        end

        def run_inference(chunk_text, goals, post, &blk)
          return if context.cancel_manager&.cancelled?

          system_prompt = goal_system_prompt(goals)
          user_prompt = goal_user_prompt(goals, chunk_text)

          prompt =
            DiscourseAi::Completions::Prompt.new(
              system_prompt,
              messages: [{ type: :user, content: user_prompt }],
              post_id: post.id,
              topic_id: post.topic_id,
            )

          results = []
          researcher_llm.generate(
            prompt,
            user: post.user,
            feature_name: context.feature_name,
            cancel_manager: context.cancel_manager,
          ) { |partial| results << partial }

          @progress_dots ||= 0
          @progress_dots += 1
          blk.call(details + "\n\n#{"." * @progress_dots}")
          results.join
        end

        def goal_system_prompt(goals)
          <<~TEXT
            You are a researcher tool designed to analyze and extract information from forum content on #{Discourse.base_url}.
            The current date is #{::Time.zone.now.strftime("%a, %d %b %Y %H:%M %Z")}.
            Your task is to process the provided content and extract relevant information based on the specified goal.
            When extracting content ALWAYS include the following:
             - Multiple citations using Markdown
               - Topic citations: Interesting fact [ref](/t/-/TOPIC_ID)
               - Post citations: Interesting fact [ref](/t/-/TOPIC_ID/POST_NUMBER)
             - Relevent quotes from the direct source content
             - Relevant dates and times from the content

            Your goal is: #{goals}
          TEXT
        end

        def goal_user_prompt(goals, chunk_text)
          <<~TEXT
            Here is the content to analyze:

            {{{
            #{chunk_text}
            }}}

            Your goal is: #{goals}
           TEXT
        end
      end
    end
  end
end
