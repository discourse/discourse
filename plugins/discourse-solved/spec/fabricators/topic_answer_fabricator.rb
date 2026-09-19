# frozen_string_literal: true
Fabricator(:topic_answer, from: DiscourseSolved::TopicAnswer) do
  solved_topic
  post { Fabricate(:post) }
  accepter { Fabricate(:user) }
end
