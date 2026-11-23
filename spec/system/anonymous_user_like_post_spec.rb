# frozen_string_literal: true

describe "Anonymous user liking a post" do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:login_page) { PageObjects::Pages::Login.new }

  before { EmailToken.confirm(Fabricate(:email_token, user:).token) }

  shared_examples "replays the like after login" do
    it "automatically likes the post after login" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :like)

      expect(login_page).to be_open

      login_page.fill(username: user.username, password: "supersecurepassword").click_login

      expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
      expect(topic_page).to have_post_action_button(post, :like_count)
      expect(post.reload.like_count).to eq(1)
    end
  end

  include_examples "replays the like after login"

  it "hides the like action in categories that disable new likes" do
    SiteSetting.disable_likes_in_categories = topic.category_id.to_s
    topic_page.visit_topic(topic)

    expect(topic_page).to have_no_post_action_button(post, :like)
  end

  context "when the topic is closed" do
    before { topic.update!(closed: true) }

    include_examples "replays the like after login"
  end
end
