# frozen_string_literal: true

require "rails_helper"

describe PostSerializer do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id) }

  before do
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    Category.reset_voting_cache
    SiteSetting.topic_voting_show_who_voted = true
    SiteSetting.topic_voting_enabled = true
  end

  it "serializes can_vote for first posts only" do
    post = Fabricate(:post, topic: topic)
    json = PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
    expect(json[:can_vote]).to eq(true)

    post = Fabricate(:post, topic: topic)
    json = PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
    expect(json[:can_vote]).to eq(nil)

    post = Fabricate(:post)
    json = PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
    expect(json[:can_vote]).to eq(false)
  end
end
