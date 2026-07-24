# frozen_string_literal: true

namespace :ai do
  desc "Generate topics with AI post content using random users and categories. Use it this way rake ai:generate_topics['title1\,title2\,title3']"
  task :generate_topics, [:titles] => [:environment] do |task, args|
    titles = args[:titles].include?(",") ? args[:titles].split(",").map(&:strip) : [args[:titles]]
    puts "Will create #{titles.size} #{"topics".pluralize(titles.size)}: #{titles.join(", ")}"

    titles.each do |title|
      next if Topic.find_by_title(TextCleaner.clean_title(TextSentinel.title_sentinel(title).text))
      category =
        Category
          .where.not(id: SiteSetting.uncategorized_category_id)
          .where(read_restricted: false)
          .order("RANDOM()")
          .first
      users = User.real.activated.not_suspended.where(staged: false).order("RANDOM()").limit(12)
      RateLimiter.disable

      creator = TopicGenerator.new(title)
      first_post = creator.get_first_post
      replies_count = rand(4..10)
      replies = creator.get_replies(replies_count, first_post)

      post = create_topic(category, first_post, title, users)
      replies.each_with_index { |reply, i| create_post(users[i + 1], post.topic_id, reply) }
      puts "'#{title}' has #{replies.size} replies"
    end
  end

  def create_topic(category, first_post, title, users)
    puts "#{users.first.username} will create topic '#{title}' in category '#{category.name}'"
    post =
      PostCreator.create!(
        users.first,
        title: title,
        raw: first_post,
        category: category.id,
        skip_guardian: true,
      )
    puts "Created topic '#{title}' (#{post.topic_id}) in category '#{category.name}'"
    post
  end

  def create_post(user, topic_id, raw)
    puts "#{user.username} will reply to topic #{topic_id}"
    PostCreator.create!(user, topic_id:, raw:, skip_guardian: true)
  end

  class TopicGenerator
    FIRST_POST_RESPONSE_FORMAT = {
      type: "json_schema",
      json_schema: {
        name: "topic_generator_first_post",
        schema: {
          type: "object",
          properties: {
            first_post: {
              type: "string",
            },
          },
          required: %w[first_post],
          additionalProperties: false,
        },
        strict: true,
      },
    }.freeze

    REPLIES_RESPONSE_FORMAT = {
      type: "json_schema",
      json_schema: {
        name: "topic_generator_replies",
        schema: {
          type: "object",
          properties: {
            replies: {
              type: "array",
              items: {
                type: "string",
              },
            },
          },
          required: %w[replies],
          additionalProperties: false,
        },
        strict: true,
      },
    }.freeze

    def initialize(title)
      @title = title
    end

    def get_first_post
      prompt = <<~PROMPT
        Write and opening topic about title: #{@title}. The title is likely regarding a fictional piece of work.
        - content must be in the same language as title
        - content in markdown
        - content should exclude the title
        - maximum of 200 words
      PROMPT

      response = TopicGenerator.generate(prompt, response_format: FIRST_POST_RESPONSE_FORMAT)

      TopicGenerator.structured_value(response, :first_post).to_s
    end

    def get_replies(count, first_post)
      prompt = <<~PROMPT
        Write #{count} replies to a topic with title #{@title}. The title is likely regarding a fictional piece of work.

        ________________

        The topic's first post has this content:
        #{first_post}

        ________________

        The replies
        - must each have a maximum of 100 words
        - keep to same language of title
        - may contain markdown to bold, italicize, link, or bullet point
      PROMPT

      response = TopicGenerator.generate(prompt, response_format: REPLIES_RESPONSE_FORMAT)

      TopicGenerator.structured_replies(response).filter_map { |reply| reply.to_s.presence }
    end

    private

    def self.generate(prompt, response_format:)
      return "" if prompt.blank?

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a forum user writing concise, informative posts. Keep responses focused and natural.",
          messages: [{ type: :user, content: prompt, id: "user" }],
        )

      DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_default_llm_model).generate(
        prompt,
        user: Discourse.system_user,
        feature_name: "topic-generator",
        response_format: response_format,
      )
    rescue => e
      Rails.logger.error("AI TopicGenerator Error: #{e.message}")
      ""
    end

    def self.structured_value(response, key)
      return response.read_buffered_property(key) if response.respond_to?(:read_buffered_property)

      parsed_response =
        response.is_a?(Hash) || response.is_a?(Array) ? response : JSON.parse(response)

      if parsed_response.is_a?(Hash)
        parsed_response[key.to_s] || parsed_response[key]
      else
        parsed_response
      end
    rescue JSON::ParserError
      response
    end

    def self.structured_replies(response)
      replies = structured_value(response, :replies)
      return replies if replies.is_a?(Array)

      parsed_replies = JSON.parse(replies) if replies.is_a?(String)
      parsed_replies.is_a?(Array) ? parsed_replies : Array(replies)
    rescue JSON::ParserError
      Array(replies)
    end
  end
end
