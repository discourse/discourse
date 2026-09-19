# frozen_string_literal: true
Fabricator(:solved_topic, from: DiscourseSolved::SolvedTopic) do
  topic
  transient :topic_answer, :answer_post

  after_create do |solved_topic, transients|
    if transients[:topic_answer]
      solved_topic.topic_answers << transients[:topic_answer]
    elsif transients[:answer_post]
      Fabricate(:topic_answer, solved_topic:, post: transients[:answer_post])
    end
  end
end
