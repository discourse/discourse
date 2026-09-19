# frozen_string_literal: true

RSpec.describe "Anonymous user voting on a topic" do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:category) { Fabricate(:category, name: "voting category") }
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    SiteSetting.topic_voting_enabled = true
    DiscourseTopicVoting::CategorySetting.create!(category_id: category.id)
    Category.reset_voting_cache
    EmailToken.confirm(Fabricate(:email_token, user:).token)
  end

  it "casts the vote automatically after login" do
    topic_page.visit_topic(topic)

    topic_page.vote

    expect(login_page).to be_open

    login_page.fill(username: user.username, password: "supersecurepassword").click_login

    expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
    expect(DiscourseTopicVoting::Vote.exists?(user: user, topic: topic)).to eq(true)
  end
end
