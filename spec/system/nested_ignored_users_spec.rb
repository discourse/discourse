# frozen_string_literal: true

RSpec.describe "Nested view ignored users" do
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:ignored_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: viewer) }
  fab!(:op) { Fabricate(:post, topic: topic, user: viewer, post_number: 1) }

  fab!(:ignored_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: ignored_author,
      reply_to_post_number: 1,
      raw: "Secret reply content from an ignored user",
    )
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:ignored_user, user: viewer, ignored_user: ignored_author)
    sign_in(viewer)
  end

  it "shows an [ignored] placeholder in place of the reply body" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_ignored_placeholder_for(ignored_reply)
    expect(page).to have_no_content("Secret reply content from an ignored user")
  end

  it "reveals the real content when the eye-slash avatar button is clicked" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_ignored_placeholder_for(ignored_reply)

    nested_view.click_reveal_ignored(ignored_reply)

    expect(nested_view).to have_no_ignored_placeholder_for(ignored_reply)
    expect(page).to have_css(
      "[data-post-number='#{ignored_reply.post_number}']",
      text: "Secret reply content from an ignored user",
    )
  end

  it "does not render an ignored placeholder for the OP even if the OP author is ignored" do
    op.update!(user: ignored_author)

    nested_view.visit_nested(topic)

    expect(nested_view).to have_no_ignored_placeholder_for(op)
  end
end
