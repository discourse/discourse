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
    topic_page.expand_post_admin_actions(reply)
    click_button I18n.t("js.topic.pinned_footer_post.pin")

    within(".topic-footer-pinned-post") do
      expect(page).to have_text(reply.raw)
      expect(page).to have_link(
        I18n.t("js.topic.pinned_footer_post.view_original"),
        href: reply.relative_url,
      )
    end
    expect(page).to have_css("#post_#{reply.post_number} .cooked", text: reply.raw)

    topic_page.expand_post_admin_actions(reply)
    click_button I18n.t("js.topic.pinned_footer_post.unpin")

    expect(page).to have_no_css(".topic-footer-pinned-post")
  end
end
