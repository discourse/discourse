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
          dynamic_map = post.custom_fields[DiscoursePoll::DYNAMIC_POLLS]
          dynamic_map =
            case dynamic_map
            when Hash
              dynamic_map
            when String
              begin
                JSON.parse(dynamic_map)
              rescue StandardError
                {}
              end
            else
              {}
            end

          polls.each do |name, poll|
            DiscoursePoll::Poll.create!(post.id, poll)
            is_dynamic = (poll["dynamic"].to_s == "true") || (poll["dynamic-poll"].to_s == "true")
            dynamic_map[name] = true if is_dynamic
          end

          post.custom_fields[DiscoursePoll::HAS_POLLS] = true
          post.custom_fields[DiscoursePoll::DYNAMIC_POLLS] = dynamic_map if dynamic_map.present?
          post.save_custom_fields(true)
        end
      end
    end
  end
end
