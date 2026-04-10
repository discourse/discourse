# frozen_string_literal: true
Fabricator(:solved_topic, from: DiscourseSolved::SolvedTopic) do
  topic
  transient :topic_answer
  transient :answer_post

  after_create do |solved_topic, transients|
    if transients[:topic_answer]
      solved_topic.topic_answers << transients[:topic_answer]
    elsif transients[:answer_post]
      Fabricate(:topic_answer, solved_topic: solved_topic, answer_post: transients[:answer_post])
    else
      Fabricate(:topic_answer, solved_topic: solved_topic)
    end
  end
end
