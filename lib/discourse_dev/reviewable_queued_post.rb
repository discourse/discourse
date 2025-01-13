# frozen_string_literal: true

require "discourse_dev/reviewable"
require "faker"

module DiscourseDev
  class ReviewableQueuedPost < Reviewable
    def populate!
      :new_topics_unless_allowed_groups.tap do |reason|
        manager =
          NewPostManager.new(
            @users.sample,
            custom_payload_for_reason(reason).merge(
              title: Faker::Lorem.sentence,
              raw: Faker::DiscourseMarkdown.sandwich(sentences: 3),
              tags: nil,
              typing_duration_msecs: Faker::Number.between(from: 2_000, to: 5_000),
              composer_open_duration_msecs: Faker::Number.between(from: 5_500, to: 10_000),
            ),
          )
        manager.enqueue(reason, creator_opts: { skip_validations: true })
      end

      %i[
        email_auth_res_enqueue
        email_spam
        post_count
        group
        fast_typer
        auto_silence_regex
        staged
        category
        contains_media
      ].each do |reason|
        topic = @topics.sample
        manager =
          NewPostManager.new(
            @users.sample,
            custom_payload_for_reason(reason).merge(
              topic_id: topic.id,
              raw: Faker::DiscourseMarkdown.sandwich(sentences: 3),
              tags: nil,
              typing_duration_msecs: Faker::Number.between(from: 2_000, to: 5_000),
              composer_open_duration_msecs: Faker::Number.between(from: 5_500, to: 10_000),
              reply_to_post_number: topic.posts.sample.post_number,
            ),
          )
        manager.enqueue(reason, creator_opts: { skip_validations: true })
      end
    end

    private

    def custom_payload_for_reason(reason)
      case reason
      when :email_auth_res_enqueue, :email_spam
        { via_email: true, raw_email: Faker::Lorem.paragraph }
      else
        {}
      end
    end
  end
end
