# frozen_string_literal: true

module DiscourseSolved
  module PostMoverExtension
    private

    # original_topic, post_ids, and user are attr_readers on PostMover
    def move_posts_to(topic)
      solved_topic = DiscourseSolved::SolvedTopic.find_by(topic: original_topic)

      if solved_topic
        topic_answers_to_move = solved_topic.topic_answers.where(answer_post_id: post_ids)

        topic_answers_to_move.each do |ta|
          target_solved_topic = DiscourseSolved::SolvedTopic.find_by(topic: topic)
          accepts_answers = Guardian.new(user).allow_accepted_answers?(topic)
          post_is_answer =
            target_solved_topic&.topic_answers&.exists?(answer_post_id: ta.answer_post_id)

          if accepts_answers && !post_is_answer
            target_solved_topic ||= DiscourseSolved::SolvedTopic.find_or_create_by!(topic: topic)
            ta.update!(solved_topic: target_solved_topic)
          else
            DiscourseSolved::UnacceptAnswer.call(
              params: {
                post_id: ta.answer_post_id,
              },
              guardian: Discourse.system_user.guardian,
            )
          end
        end

        solved_topic.reload.destroy! if solved_topic.topic_answers.none?
      end

      super
    end
  end
end
