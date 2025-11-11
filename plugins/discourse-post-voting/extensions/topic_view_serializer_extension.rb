# frozen_string_literal: true

module PostVoting
  module TopicViewSerializerExtension
    def self.included(base)
      base.attributes(
        :is_post_voting,
        :last_answered_at,
        :last_commented_on,
        :answer_count,
        :last_answer_post_number,
        :last_answerer,
      )
    end

    def is_post_voting
      true
    end

    def include_is_post_voting?
      object.topic.is_post_voting?
    end

    def last_answered_at
      object.topic.last_answered_at
    end

    def include_last_answered_at?
      object.topic.is_post_voting?
    end

    def last_commented_on
      object.topic.last_commented_on
    end

    def include_last_commented_on?
      object.topic.is_post_voting?
    end

    def answer_count
      object.topic.answer_count
    end

    def include_answer_count?
      object.topic.is_post_voting?
    end

    def last_answer_post_number
      object.topic.last_answer_post_number
    end

    def include_last_answer_post_number?
      object.topic.is_post_voting?
    end

    def last_answerer
      BasicUserSerializer.new(object.topic.last_answerer, scope: scope, root: false).as_json
    end

    def include_last_answerer?
      object.topic.is_post_voting?
    end
  end
end
