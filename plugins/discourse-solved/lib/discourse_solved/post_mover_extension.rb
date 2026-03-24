# frozen_string_literal: true

module DiscourseSolved
  module PostMoverExtension
    private

    # original_topic, post_ids, and user are attr_readers on PostMover
    def move_posts_to(topic)
      solved_topic = DiscourseSolved::SolvedTopic.find_by(topic_id: original_topic.id)

      if solved_topic && post_ids.include?(solved_topic.answer_post_id)
        accepts_answers = Guardian.new(user).allow_accepted_answers?(topic)
        has_no_solution = !DiscourseSolved::SolvedTopic.exists?(topic_id: topic.id)

        if accepts_answers && has_no_solution
          solved_topic.update!(topic_id: topic.id)
        else
          DiscourseSolved::UnacceptAnswer.call(
            params: {
              post_id: solved_topic.answer_post_id,
            },
            guardian: Discourse.system_user.guardian,
          )
        end
      end

      super
    end
  end
end
