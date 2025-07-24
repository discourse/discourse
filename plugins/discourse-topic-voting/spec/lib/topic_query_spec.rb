# frozen_string_literal: true

describe TopicQuery do
  fab!(:user0) { Fabricate(:user) }
  fab!(:category1) { Fabricate(:category) }
  fab!(:topic0) { Fabricate(:topic, category: category1) }
  fab!(:topic1) { Fabricate(:topic, category: category1) }
  fab!(:vote) { DiscourseTopicVoting::Vote.create!(topic_id: topic1.id, user_id: user0.id) }
  fab!(:topic_vote_count) do
    DiscourseTopicVoting::TopicVoteCount.create!(topic_id: topic1.id, votes_count: 1)
  end

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.topic_voting_show_who_voted = true
  end

  it "order topic by votes" do
    expect(TopicQuery.new(user0, { order: "votes" }).list_latest.topics.map(&:id)).to eq(
      [topic1.id, topic0.id],
    )
  end

  it "returns topics voted by user" do
    expect(TopicQuery.new(user0, { state: "my_votes" }).list_latest.topics.map(&:id)).to eq(
      [topic1.id],
    )
  end

  it "orders topic by bumped_at if votes are equal" do
    topic2 = Fabricate(:topic, category: category1, bumped_at: 2.hours.ago)
    DiscourseTopicVoting::TopicVoteCount.create!(topic_id: topic2.id, votes_count: 2)
    topic3 = Fabricate(:topic, category: category1, bumped_at: 3.hours.ago)
    topic4 = Fabricate(:topic, category: category1, bumped_at: 1.hour.ago)

    opts = { order: "votes", per_page: 2, category: category1.slug }
    expect(TopicQuery.new(user0, opts).list_latest.topics.map(&:id)).to eq([topic2.id, topic1.id])
    expect(TopicQuery.new(user0, opts.merge(page: 1)).list_latest.topics.map(&:id)).to eq(
      [topic0.id, topic4.id],
    )
    expect(TopicQuery.new(user0, opts.merge(page: 2)).list_latest.topics.map(&:id)).to eq(
      [topic3.id],
    )
  end
end
