#frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Search < Tool
        attr_reader :last_query

        MIN_SEMANTIC_RESULTS = 5

        class << self
          def signature
            {
              name: name,
              description:
                "Will search topics in the current discourse instance, when rendering always prefer to link to the topics you find",
              parameters: [
                {
                  name: "search_query",
                  description:
                    "Specific keywords to search for, space separated (correct bad spelling, remove connector words)",
                  type: "string",
                },
                {
                  name: "user",
                  description:
                    "Filter search results to this username (only include if user explicitly asks to filter by user)",
                  type: "string",
                },
                {
                  name: "order",
                  description: "search result order",
                  type: "string",
                  enum: %w[latest latest_topic oldest views likes],
                },
                {
                  name: "max_results",
                  description:
                    "limit number of results returned (generally prefer to just keep to default)",
                  type: "integer",
                },
                {
                  name: "max_posts",
                  description:
                    "maximum number of posts on the topics (topics where lots of people posted)",
                  type: "integer",
                },
                {
                  name: "tags",
                  description:
                    "list of tags to search for. Use + to join with OR, use , to join with AND",
                  type: "string",
                },
                { name: "category", description: "category name to filter to", type: "string" },
                {
                  name: "before",
                  description: "only topics created before a specific date YYYY-MM-DD",
                  type: "string",
                },
                {
                  name: "after",
                  description: "only topics created after a specific date YYYY-MM-DD",
                  type: "string",
                },
                {
                  name: "status",
                  description: "search for topics in a particular state",
                  type: "string",
                  enum: %w[open closed archived noreplies single_user],
                },
              ],
            }
          end

          def name
            "search"
          end

          def custom_system_message
            <<~TEXT
            You were trained on OLD data, lean on search to get up to date information about this forum
            When searching try to SIMPLIFY search terms
            Discourse search joins all terms with AND. Reduce and simplify terms to find more results.
          TEXT
          end

          def accepted_options
            [
              option(:base_query, type: :string),
              option(:max_results, type: :integer),
              option(:search_private, type: :boolean),
            ]
          end
        end

        def search_args
          parameters.slice(:category, :user, :order, :max_posts, :tags, :before, :after, :status)
        end

        def search_query
          parameters[:search_query]
        end

        def invoke
          search_terms = []
          search_terms << options[:base_query] if options[:base_query].present?
          search_terms << search_query if search_query.present?
          search_args.each { |key, value| search_terms << "#{key}:#{value}" if value.present? }

          @last_query = search_terms.join(" ").to_s

          yield(I18n.t("discourse_ai.ai_bot.searching", query: @last_query))

          max_results = calculate_max_results(llm)
          if parameters[:max_results].to_i > 0
            max_results = [parameters[:max_results].to_i, max_results].min
          end

          search_query_with_base = [options[:base_query], search_query].compact.join(" ").strip

          results =
            DiscourseAi::Utils::Search.perform_search(
              search_query: search_query_with_base,
              category: parameters[:category],
              user: parameters[:user],
              order: parameters[:order],
              max_posts: parameters[:max_posts],
              tags: parameters[:tags],
              before: parameters[:before],
              after: parameters[:after],
              status: parameters[:status],
              max_results: max_results,
              current_user: options[:search_private] ? context.user : nil,
            )

          @last_num_results = results[:rows]&.length || 0
          results
        end

        protected

        def description_args
          {
            count: @last_num_results || 0,
            query: @last_query || "",
            url: "#{Discourse.base_path}/search?q=#{CGI.escape(@last_query || "")}",
          }
        end

        private

        def calculate_max_results(llm)
          max_results = options[:max_results].to_i
          return [max_results, 100].min if max_results > 0

          if llm.max_prompt_tokens > 30_000
            60
          elsif llm.max_prompt_tokens > 10_000
            40
          else
            20
          end
        end
      end
    end
  end
end
