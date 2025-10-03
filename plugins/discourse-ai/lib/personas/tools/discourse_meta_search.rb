#frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class DiscourseMetaSearch < Tool
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
            "search_meta_discourse"
          end

          def custom_system_message
            <<~TEXT
            You were trained on OLD data, lean on search to get up to date information
            Discourse search joins all terms with AND. Reduce and simplify terms to find more results.
          TEXT
          end
        end

        def search_args
          parameters.slice(:category, :user, :order, :max_posts, :tags, :before, :after, :status)
        end

        def invoke
          search_string =
            search_args.reduce(+parameters[:search_query].to_s) do |memo, (key, value)|
              return memo if value.blank?
              memo << " " << "#{key}:#{value}"
            end

          @last_query = search_string

          yield(I18n.t("discourse_ai.ai_bot.searching", query: search_string))

          if options[:base_query].present?
            search_string = "#{search_string} #{options[:base_query]}"
          end

          url = "https://meta.discourse.org/search.json?q=#{CGI.escape(search_string)}"

          json = JSON.parse(Net::HTTP.get(URI(url)))

          # let's be frugal with tokens, 50 results is too much and stuff gets cut off
          max_results = calculate_max_results(llm)
          results_limit = parameters[:limit] || max_results
          results_limit = max_results if parameters[:limit].to_i > max_results

          posts = json["posts"] || []
          posts = posts[0..results_limit.to_i - 1]

          @last_num_results = posts.length

          if posts.blank?
            { args: parameters, rows: [], instruction: "nothing was found, expand your search" }
          else
            categories =
              if categories_json = json.dig("grouped_search_result", "extra", "categories")
                categories_json.map { |c| [c["id"], c] }.to_h
              else
                self.class.categories
              end

            topics = (json["topics"]).map { |t| [t["id"], t] }.to_h

            format_results(posts, args: parameters) do |post|
              topic = topics[post["topic_id"]]

              category = categories[topic["category_id"]]
              category_names = +""
              # TODO @nbianca: this is broken now cause we are not getting child categories
              # to avoid erroring out we simply skip
              # sideloading from search would probably be easier
              if category
                if category["parent_category_id"]
                  category_names << categories[category["parent_category_id"]]["name"] << " > "
                end
                category_names << category["name"]
              end
              row = {
                title: topic["title"],
                url: "https://meta.discourse.org/t/-/#{post["topic_id"]}/#{post["post_number"]}",
                username: post["username"],
                excerpt: post["blurb"],
                created: post["created_at"],
                category: category_names,
                likes: post["like_count"],
                tags: topic["tags"].join(", "),
              }

              row
            end
          end
        end

        protected

        def self.categories
          return @categories if defined?(@categories)

          url = "https://meta.discourse.org/site.json"
          json = JSON.parse(Net::HTTP.get(URI(url)))
          @categories =
            json["categories"]
              .map do |c|
                [c["id"], { "name" => c["name"], "parent_category_id" => c["parent_category_id"] }]
              end
              .to_h
        end

        def description_args
          {
            count: @last_num_results || 0,
            query: @last_query || "",
            url: "https://meta.discourse.org/search?q=#{CGI.escape(@last_query || "")}",
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
