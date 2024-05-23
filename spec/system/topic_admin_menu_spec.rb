# frozen_string_literal: true

describe "Topic Admin Menu", type: :system do
  fab!(:admin)
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(admin) }

  context "for a PM" do
    fab!(:pm) { Fabricate(:private_message_topic, title: "Can you help me with this?") }
    fab!(:op) { Fabricate(:post, topic: pm, user: admin, created_at: 1.day.ago) }
    fab!(:category)

    it "shows the errors when converting to a public topic is not possible" do
      # create a topic with the same title to force a "duplicate title" error
      Fabricate(:topic, title: pm.title, category: category)

      topic_page.visit_topic(pm)
      topic_page.move_to_public_category(category)
      expect(topic_page.move_to_public_modal).to have_css("#modal-alert")
    end
  end
end
