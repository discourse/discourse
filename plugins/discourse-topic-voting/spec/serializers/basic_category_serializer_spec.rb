# frozen_string_literal: true

describe BasicCategorySerializer do
  fab!(:category)

  it "does not return can_vote when voting disabled" do
    SiteSetting.topic_voting_enabled = false

    json = BasicCategorySerializer.new(category, root: false).as_json

    expect(json[:can_vote]).to eq(nil)
  end

  it "does not return can_vote when voting disabled" do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)

    json = BasicCategorySerializer.new(category, root: false).as_json

    expect(json[:can_vote]).to eq(true)
  end
end
