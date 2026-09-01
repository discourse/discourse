# frozen_string_literal: true

describe BasicCategorySerializer do
  fab!(:category)

  it "omits can_vote when voting is disabled" do
    SiteSetting.topic_voting_enabled = false

    json = BasicCategorySerializer.new(category, root: false).as_json

    expect(json[:can_vote]).to eq(nil)
  end

  it "returns can_vote when voting is enabled for the category" do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)

    json = BasicCategorySerializer.new(category, root: false).as_json

    expect(json[:can_vote]).to eq(true)
  end
end
