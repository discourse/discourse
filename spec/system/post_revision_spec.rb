# frozen_string_literal: true

describe "Post revisions" do
  fab!(:admin)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user:) }
  fab!(:post) { Fabricate(:post, topic:, user:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_component) { PageObjects::Components::Post.new(1) }

  before { SiteSetting.tagging_enabled = true }

  describe "hidden revisions from hidden tags" do
    before do
      create_hidden_tags(["secret"])
      PostRevisor.new(post).revise!(admin, tags: ["secret"])
    end

    it "does not show the edits indicator to regular users" do
      sign_in(user)
      topic_page.visit_topic(topic)
      expect(post_component).to have_no_edits_indicator
    end

    it "shows the edits indicator to staff" do
      sign_in(admin)
      topic_page.visit_topic(topic)
      expect(post_component).to have_edits_indicator
    end
  end
end
