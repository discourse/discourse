# frozen_string_literal: true

RSpec.describe "Category default view of votes" do
  fab!(:category)
  fab!(:most_voted) { Fabricate(:topic, category:, bumped_at: 2.days.ago) }
  fab!(:recently_bumped) { Fabricate(:topic, category:, bumped_at: 1.minute.ago) }

  before do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category:)
    Category.reset_voting_cache
    category.update!(default_view: "votes")
    DiscourseTopicVoting::TopicVoteCount.create!(topic: most_voted, votes_count: 5)
  end

  def topic_ids_for(url)
    get url
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
  end

  it "orders the category by votes" do
    expect(topic_ids_for("/c/#{category.slug}/#{category.id}.json")).to eq(
      [most_voted.id, recently_bumped.id],
    )
  end

  it "orders the category by votes when excluding subcategories" do
    expect(topic_ids_for("/c/#{category.slug}/#{category.id}/none.json")).to eq(
      [most_voted.id, recently_bumped.id],
    )
  end

  it "preloads the votes ordered list into the page" do
    get "/c/#{category.slug}/#{category.id}"
    expect(response.status).to eq(200)

    preloaded = Nokogiri.HTML5(response.body).at_css("#data-preloaded").text
    topic_list = JSON.parse(JSON.parse(preloaded)["topic_list"])["topic_list"]

    expect(topic_list["topics"].map { |topic| topic["id"] }).to eq(
      [most_voted.id, recently_bumped.id],
    )
  end
end
