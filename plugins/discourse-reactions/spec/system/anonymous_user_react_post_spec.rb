# frozen_string_literal: true

describe "Anonymous user reacting to a post" do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    SiteSetting.discourse_reactions_enabled = true
    EmailToken.confirm(Fabricate(:email_token, user:).token)
  end

  shared_examples "replays the reaction after login" do
    it "applies the main reaction automatically after login" do
      visit(topic.url)

      find("#post_#{post.post_number} .discourse-reactions-reaction-button").click

      expect(login_page).to be_open

      login_page.fill(username: user.username, password: "supersecurepassword").click_login

      expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
      expect(post.reload.like_count).to eq(1)
    end
  end

  include_examples "replays the reaction after login"

  context "when the topic is closed" do
    before { topic.update!(closed: true) }

    include_examples "replays the reaction after login"
  end
end
