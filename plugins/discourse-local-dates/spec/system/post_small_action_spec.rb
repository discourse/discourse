# frozen_string_literal: true

describe "Post small actions", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  it "applies local date decorations" do
    post =
      Fabricate(
        :small_action,
        raw: "[date=2023-11-15 timezone=\"America/Los_Angeles\"] a date",
        topic: topic,
      )

    topic_page.visit_topic(topic)
    expect(topic_page).to have_post_number(post.post_number)

    expect(page).to have_css(".small-action-custom-message .discourse-local-date.cooked-date")
  end
end
