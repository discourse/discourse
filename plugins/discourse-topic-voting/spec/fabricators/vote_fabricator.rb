# frozen_string_literal: true

Fabricator(:topic_voting_votes, class_name: "DiscourseTopicVoting::Vote") do
  user
  topic
end
