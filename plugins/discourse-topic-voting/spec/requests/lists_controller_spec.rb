# frozen_string_literal: true

describe ListController do
  fab!(:user)
  fab!(:topic)
  # "topics/voted-by/:username"
  before { SiteSetting.topic_voting_enabled = true }

  it "allow anons to view votes" do
    user.update!(trust_level: TrustLevel[2])
    archived_topic = Fabricate(:topic)
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
    DiscourseTopicVoting::Vote.create!(user: user, topic: archived_topic, archive: true)

    get "/topics/voted-by/#{user.username}.json"
    topic_ids = response.parsed_body.dig("topic_list", "topics").pluck("id")

    expect(topic_ids).to eq([topic.id])
  end

  it "returns a 404 when we don't show votes on profiles" do
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
    SiteSetting.topic_voting_show_votes_on_profile = false

    get "/topics/voted-by/#{user.username}.json"

    expect(response.status).to eq(404)
  end

  it "returns a 404 when the target user hides their profile" do
    user.update!(trust_level: TrustLevel[2])
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)

    get "/topics/voted-by/#{user.username}.json"
    expect(response.status).to eq(200)

    SiteSetting.allow_users_to_hide_profile = true
    user.user_option.update!(hide_profile: true)

    get "/topics/voted-by/#{user.username}.json"
    expect(response.status).to eq(404)
  end

  it "returns a 404 when the user activity tab is hidden site-wide" do
    user.update!(trust_level: TrustLevel[2])
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)

    get "/topics/voted-by/#{user.username}.json"
    expect(response.status).to eq(200)

    SiteSetting.hide_user_activity_tab = true

    get "/topics/voted-by/#{user.username}.json"
    expect(response.status).to eq(404)
  end

  it "still allows the user to view their own votes when activity tab is hidden" do
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
    SiteSetting.hide_user_activity_tab = true
    SiteSetting.allow_users_to_hide_profile = true
    user.user_option.update!(hide_profile: true)
    sign_in(user)

    get "/topics/voted-by/#{user.username}.json"
    topic_ids = response.parsed_body.dig("topic_list", "topics").pluck("id")

    expect(response.status).to eq(200)
    expect(topic_ids).to eq([topic.id])
  end

  context "in a category" do
    fab!(:category1, :category)
    fab!(:category2, :category)
    fab!(:topic1) do
      Fabricate(:topic, category: category1, title: "Topic in votes-enabled category 1")
    end
    fab!(:topic2) do
      Fabricate(:topic, category: category2, title: "Topic in votes-enabled category 2")
    end

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: category1)
      DiscourseTopicVoting::CategorySetting.create!(category: category2)
    end

    it "allows anons to view votes RSS feed" do
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic2)

      get "/c/#{category2.slug}/#{category2.id}/l/votes.rss"

      expect(response.status).to eq(200)
      expect(response.body).to include(topic2.title)
      # ensure we don't include votes from other categories
      expect(response.body).not_to include(topic1.title)
    end
  end
end
