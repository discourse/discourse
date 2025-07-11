# frozen_string_literal: true

describe TopicListItemSerializer do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id) }
  let(:guardian) { Guardian.new(user) }

  it "excludes properties when voting disabled" do
    SiteSetting.topic_voting_enabled = false

    json = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json

    expect(json[:vote_count]).to eq nil
    expect(json[:user_voted]).to eq nil
    expect(json[:can_vote]).to eq nil
  end

  it "adds can_vote when enabled" do
    SiteSetting.topic_voting_enabled = true
    json = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json

    expect(json[:vote_count]).to eq nil
    expect(json[:user_voted]).to eq nil
    expect(json[:can_vote]).to eq false
  end

  it "updates vote count to 0 when topic is votable" do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    json = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json

    expect(json[:vote_count]).to eq 0
    expect(json[:user_voted]).to eq false
    expect(json[:can_vote]).to eq true
  end

  it "returns all the values" do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    Fabricate(:topic_voting_votes, user: user, topic: topic)
    Fabricate(:topic_voting_vote_count, topic: topic)
    json = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json

    expect(json[:vote_count]).to eq 1
    expect(json[:user_voted]).to eq true
    expect(json[:can_vote]).to eq true
  end
end
