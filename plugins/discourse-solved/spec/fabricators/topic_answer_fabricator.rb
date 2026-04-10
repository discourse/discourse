# frozen_string_literal: true
Fabricator(:topic_answer, from: DiscourseSolved::TopicAnswer) do
  solved_topic
  transient :answer_post
  answer_post_id { |t| t[:answer_post]&.id || Fabricate(:post).id }
  accepter { Fabricate(:user) }
end
