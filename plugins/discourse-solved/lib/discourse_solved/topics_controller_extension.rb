# frozen_string_literal: true

module DiscourseSolved
  module TopicsControllerExtension
    def move_posts
      post_ids = params[:post_ids]
      topic_id = params[:topic_id]

      if post_ids.present? && topic_id.present?
        topic = Topic.with_deleted.find_by(id: topic_id)

        if topic&.solved.present?
          solution_post_id = topic.solved.answer_post_id
          if post_ids.map(&:to_i).include?(solution_post_id)
            solution_post = Post.find_by(id: solution_post_id)
            DiscourseSolved.unaccept_answer!(solution_post) if solution_post
          end
        end
      end

      super
    end
  end
end
