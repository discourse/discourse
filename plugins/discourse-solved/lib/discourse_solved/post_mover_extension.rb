# frozen_string_literal: true

module DiscourseSolved
  module PostMoverExtension
    private

    def move_posts_to(topic)
      solved_topic = DiscourseSolved::SolvedTopic.find_by(topic_id: original_topic.id)

      if solved_topic && post_ids.include?(solved_topic.answer_post_id)
        if DiscourseSolved::SolvedTopic.exists?(topic_id: topic.id)
          solved_topic.destroy!
        else
          solved_topic.update!(topic_id: topic.id)
        end
      end

      super
    end
  end
end
