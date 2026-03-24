#frozen_string_literal: true

module DiscourseAi
  module Agents
    MAX_POSTS = 100

    module Tools
      class Read < Tool
        def self.signature
          {
            name: name,
            description: "Will read a topic or a post on this Discourse instance",
            parameters: [
              {
                name: "topic_id",
                description: "the id of the topic to read",
                type: "integer",
                required: true,
              },
              {
                name: "post_numbers",
                description: "the post numbers to read (optional)",
                type: "array",
                item_type: "integer",
                required: false,
              },
            ],
          }
        end

        def self.accepted_options
          [option(:read_private, type: :boolean)]
        end

        def self.name
          "read"
        end

        attr_reader :title, :url

        def topic_id
          parameters[:topic_id]
        end

        def post_numbers
          parameters[:post_numbers]
        end

        def invoke
          not_found = { topic_id: topic_id, description: "Topic not found" }
          guardian = Guardian.new(context.user) if options[:read_private] && context.user
          guardian ||= Guardian.new

          @title = ""

          topic = Topic.find_by(id: topic_id.to_i)
          return not_found if !topic || !guardian.can_see?(topic)

          @title = topic.title

          posts =
            Post.secured(guardian).where(topic_id: topic_id).order(:post_number).limit(MAX_POSTS)

          post_number = 1
          post_number = post_numbers.first if post_numbers.present?

          @url = topic.relative_url(post_number)

          posts = posts.where("post_number in (?)", post_numbers) if post_numbers.present?

          content = +<<~TEXT.strip
          title: #{topic.title}
          TEXT

          category_names = [
            topic.category&.parent_category&.name,
            topic.category&.name,
          ].compact.join(" ")
          content << "\ncategories: #{category_names}" if category_names.present?

          if topic.tags.length > 0
            tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new)
            content << "\ntags: #{tags.map(&:name).join(", ")}\n\n" if tags.length > 0
          end

          posts.each do |post|
            content << "\n\n#{post.user&.name}(#{post.username}) said:\n\n#{post.raw}"
          end

          truncated_content =
            truncate(content, max_length: 20_000, percent_length: 0.3, llm: llm).squish

          result = { topic_id: topic_id, content: truncated_content }
          result[:post_numbers] = post_numbers if post_numbers.present?
          result
        end

        protected

        def description_args
          { title: title, url: url }
        end
      end
    end
  end
end
