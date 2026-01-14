# frozen_string_literal: true

module DiscourseDev
  class DiscourseSolved
    def self.populate(plugin)
      plugin.on(:after_populate_dev_records) do |records, type|
        next unless SiteSetting.solved_enabled

        if type == :category
          next if SiteSetting.allow_solved_on_all_topics

          solved_category =
            DiscourseDev::Record.random(
              ::Category.where(
                read_restricted: false,
                id: records.pluck(:id),
                parent_category_id: nil,
              ),
            )
          ::CategoryCustomField.create!(
            category_id: solved_category.id,
            name: ::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
            value: "true",
          )
          puts "discourse-solved enabled on category '#{solved_category.name}' (#{solved_category.id})."
        elsif type == :topic
          topics = ::Topic.where(id: records.pluck(:id))

          unless SiteSetting.allow_solved_on_all_topics
            solved_category_id =
              ::CategoryCustomField
                .where(name: ::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD, value: "true")
                .first
                .category_id

            unless topics.exists?(category_id: solved_category_id)
              topics.last.update(category_id: solved_category_id)
            end

            topics = topics.where(category_id: solved_category_id)
          end

          solved_topic = DiscourseDev::Record.random(topics)
          post = nil

          if solved_topic.posts_count > 1
            post = DiscourseDev::Record.random(solved_topic.posts.where.not(post_number: 1))
          else
            post = DiscourseDev::Post.new(solved_topic, 1).create!
          end

          ::DiscourseSolved.accept_answer!(post, post.topic.user, topic: post.topic)
        end
      end
    end
  end
end
