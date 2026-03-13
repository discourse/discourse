# frozen_string_literal: true

module DiscourseSolved
  module PostMoverExtension
    private

    # original_topic and post_ids are attr_readers on PostMover
    def move_posts_to(topic)
      solved_topic = DiscourseSolved::SolvedTopic.find_by(topic_id: original_topic.id)

      if solved_topic && post_ids.include?(solved_topic.answer_post_id)
        if DiscourseSolved::SolvedTopic.exists?(topic_id: topic.id)
          DiscourseSolved::UnacceptAnswer.call(
            params: {
              post_id: solved_topic.answer_post_id,
            },
            guardian: Discourse.system_user.guardian,
          )
        else
          solved_topic.update!(topic_id: topic.id)
        end
      end

      super
    end
  end
end
