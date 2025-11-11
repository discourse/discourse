# frozen_string_literal: true

Fabricator(:topic_voting_vote_count, class_name: "DiscourseTopicVoting::TopicVoteCount") do
  topic
  votes_count 1
end
