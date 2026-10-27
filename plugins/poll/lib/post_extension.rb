# frozen_string_literal: true

module DiscoursePoll
  module PostExtension
    extend ActiveSupport::Concern

    def publish_poll_message!(payload)
      # Topic access alone does not grant access to a hidden post's poll content.
      return if hidden?

      publish_message!("/polls/#{topic_id}", payload)
    end

    prepended do
      attr_accessor :extracted_polls

      has_many :polls, dependent: :destroy

      after_save do
        polls = extracted_polls
        self.extracted_polls = nil
        next if polls.blank? || !polls.is_a?(Hash)
        post = self

        ::Poll.transaction do
          polls.each { |name, poll| DiscoursePoll::Poll.create!(post.id, poll) }

          post.custom_fields[DiscoursePoll::HAS_POLLS] = true
          post.save_custom_fields(true)
        end
      end
    end
  end
end
