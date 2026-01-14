# frozen_string_literal: true
Fabricator(:solved_topic, from: DiscourseSolved::SolvedTopic) do
  topic
  answer_post { Fabricate(:post) }
  accepter { Fabricate(:user) }
end
