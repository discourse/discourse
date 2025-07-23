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
      replies = creator.get_replies(replies_count)

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
    def initialize(title)
      @title = title
    end

    def get_first_post
      TopicGenerator.generate(<<~PROMPT)
        Write and opening topic about title: #{@title}.
        - content must be in the same language as title
        - content in markdown
        - content should exclude the title
        - maximum of 200 words
      PROMPT
    end

    def get_replies(count)
      JSON.parse(
        TopicGenerator.generate(<<~PROMPT).gsub(/```json\n?|\```/, "").gsub(/,\n\n/, ",\n").strip,
                Write #{count} replies to a topic with title #{@title}.
                - respond in an array of strings within double quotes ["", "", ""]
                - each with a maximum of 100 words
                - keep to same language of title
                - each reply may contain markdown to bold, italicize, link, or bullet point
                - do not return anything else other than the array
                - the last item in the array should not have a trailing comma
                - Example return value ["I agree with you. So and so...", "It is fun ... etc"]
              PROMPT
      )
    end

    private

    def self.generate(prompt)
      return "" if prompt.blank?

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a forum user writing concise, informative posts. Keep responses focused and natural.",
          messages: [{ type: :user, content: prompt, id: "user" }],
        )

      DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
        prompt,
        user: Discourse.system_user,
        feature_name: "topic-generator",
      )
    rescue => e
      Rails.logger.error("AI TopicGenerator Error: #{e.message}")
      ""
    end
  end
end
