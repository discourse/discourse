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
          can_have_more_answers =
            SiteSetting.solved_allow_multiple_solutions ||
              !target_solved_topic&.topic_answers.present?

          if accepts_answers && can_have_more_answers
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

        solved_topic = DiscourseSolved::SolvedTopic.find_by(id: solved_topic.id)
        solved_topic&.destroy! if solved_topic&.topic_answers&.none?
      end

      super
    end
  end
end
