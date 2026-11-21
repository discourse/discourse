# frozen_string_literal: true

describe "Pinned topic footer post" do
  fab!(:first_post, :post)
  fab!(:reply) do
    Fabricate(:post, topic: first_post.topic, raw: "This is the staff clarification.")
  end
  fab!(:moderator)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "lets staff pin and unpin a copy of a reply in the footer" do
    SiteSetting.enable_pin_post_to_topic_footer = true
    sign_in(moderator)
    topic_page.visit_topic(first_post.topic)

    topic_page.expand_post_actions(reply)
    topic_page.click_footer_pin_action(reply, :pin)

    expect(topic_page).to have_pinned_footer_post(reply)
    expect(topic_page).to have_post_content(post_number: reply.post_number, content: reply.raw)

    topic_page.click_footer_pin_action(reply, :unpin)

    expect(topic_page).to have_no_pinned_footer_post
  end
end
