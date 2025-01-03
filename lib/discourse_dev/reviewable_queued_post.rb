# frozen_string_literal: true

require "discourse_dev/reviewable"
require "faker"

module DiscourseDev
  class ReviewableQueuedPost < Reviewable
    def populate!
      2.times do
        topic = @topics.sample
        manager =
          NewPostManager.new(
            @users.sample,
            {
              topic_id: topic.id,
              raw: Faker::DiscourseMarkdown.sandwich(sentences: 3),
              tags: nil,
              typing_duration_msecs: Faker::Number.between(from: 2_000, to: 5_000),
              composer_open_duration_msecs: Faker::Number.between(from: 5_500, to: 10_000),
              reply_to_post_number: topic.posts.sample.post_number,
            },
          )
        manager.enqueue(:watched_word, creator_opts: { skip_validations: true })
      end
    end
  end
end
