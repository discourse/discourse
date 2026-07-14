# frozen_string_literal: true

describe "Anonymous user voting on a poll" do
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, raw: <<~RAW) }
      [poll type=regular results=always]
      * Option A
      * Option B
      [/poll]
    RAW

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:poll_page) { PageObjects::Pages::Poll.new(topic_page:) }
  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    SiteSetting.poll_enabled = true
    EmailToken.confirm(Fabricate(:email_token, user:).token)
  end

  shared_examples "replays the vote after login" do
    it "casts the vote automatically after login (single-choice poll)" do
      topic_page.visit_topic(topic)

      poll_page.vote_for_option(post, "Option A")

      expect(login_page).to be_open

      login_page.fill(username: user.username, password: "supersecurepassword").click_login

      expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
      expect(PollVote.where(user: user).count).to eq(1)
    end
  end

  include_examples "replays the vote after login"

  context "when the topic is closed" do
    before { topic.update!(closed: true) }

    include_examples "replays the vote after login"
  end
end
