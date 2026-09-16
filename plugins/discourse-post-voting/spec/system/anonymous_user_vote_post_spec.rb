# frozen_string_literal: true

RSpec.describe "Anonymous user voting on a post" do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: topic_author) }
  fab!(:question) { Fabricate(:post, topic:, user: topic_author) }
  fab!(:answer) { Fabricate(:post, topic:, user: topic_author) }

  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    SiteSetting.post_voting_enabled = true
    EmailToken.confirm(Fabricate(:email_token, user:).token)
  end

  it "casts the upvote automatically after login" do
    visit(topic.url)

    find("#post_#{answer.post_number} .post-voting-post button.post-voting-button.--upvote").click

    expect(login_page).to be_open

    login_page.fill(username: user.username, password: "supersecurepassword").click_login

    expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
    expect(PostVotingVote.exists?(votable: answer, user: user, direction: "up")).to eq(true)
  end
end
