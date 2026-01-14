# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-topic-voting/db/migrate/20240711102255_ensure_consistency.rb",
        )

describe EnsureConsistency do
  it "ensures consistency" do
    user = Fabricate(:user)
    user2 = Fabricate(:user)

    no_vote_topic = Fabricate(:topic)
    DiscourseTopicVoting::TopicVoteCount.create!(topic: no_vote_topic, votes_count: 10)

    one_vote_topic = Fabricate(:topic)
    DiscourseTopicVoting::TopicVoteCount.create!(topic: one_vote_topic, votes_count: 10)

    two_vote_topic = Fabricate(:topic)

    # one vote
    DiscourseTopicVoting::Vote.create!(user: user, topic: one_vote_topic, archive: true)

    # two votes
    DiscourseTopicVoting::Vote.create!(user: user, topic: two_vote_topic, archive: true)
    second_vote = DiscourseTopicVoting::Vote.create!(user: user2, topic: two_vote_topic)

    EnsureConsistency.new.up

    no_vote_topic.reload

    expect(DiscourseTopicVoting::Vote.where(user: user).pluck(:topic_id)).to eq(
      [one_vote_topic.id, two_vote_topic.id],
    )
    expect(DiscourseTopicVoting::Vote.where(user: user2).pluck(:topic_id)).to eq(
      [two_vote_topic.id],
    )

    one_vote_topic.reload
    expect(one_vote_topic.topic_vote_count.votes_count).to eq(1)

    two_vote_topic.reload
    expect(two_vote_topic.topic_vote_count.votes_count).to eq(2)

    # ensure deleted user has their vote deleted
    user2.destroy
    expect { second_vote.reload }.to raise_error(ActiveRecord::RecordNotFound)

    # ensure no topic vote counts if topic doesn't exist
    topic_to_delete = Fabricate(:topic)
    topic_vote_count =
      DiscourseTopicVoting::TopicVoteCount.create!(topic: topic_to_delete, votes_count: 10)
    topic_to_delete.destroy
    expect { topic_vote_count.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
