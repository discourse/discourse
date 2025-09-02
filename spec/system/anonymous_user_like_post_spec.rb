# frozen_string_literal: true

describe "Anonymous user liking a post", type: :system do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:login_page) { PageObjects::Pages::Login.new }

  before { EmailToken.confirm(Fabricate(:email_token, user:).token) }

  it "automatically likes the post after login" do
    expect(post.like_count).to eq(0)

    topic_page.visit_topic(topic)

    expect(topic_page).to have_no_who_liked_on_post(post)

    topic_page.click_post_action_button(post, :like)

    expect(login_page).to be_open

    login_page.fill(username: user.username, password: "supersecurepassword").click_login

    expect(page).to have_current_path(topic.url)

    topic_page.click_post_action_button(post, :like_count)

    expect(topic_page).to have_who_liked_on_post(post, count: 1)

    expect(post.reload.like_count).to eq(1)
  end
end
