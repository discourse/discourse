# frozen_string_literal: true

module DiscoursePoll
  module PostExtension
    extend ActiveSupport::Concern

    prepended do
      attr_accessor :extracted_polls

      has_many :polls, dependent: :destroy

      after_save do
        polls = self.extracted_polls
        self.extracted_polls = nil
        next if polls.blank? || !polls.is_a?(Hash)
        post = self

        ::Poll.transaction do
          polls.values.each { |poll| DiscoursePoll::Poll.create!(post.id, poll) }
          post.custom_fields[DiscoursePoll::HAS_POLLS] = true
          post.save_custom_fields(true)
        end
      end
    end
  end
end
