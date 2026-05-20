# frozen_string_literal: true

RSpec.describe "Nested view copy link" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:cdp) { PageObjects::CDP.new }

  fab!(:root_reply) do
    Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply content")
  end

  fab!(:child_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: Fabricate(:user),
      raw: "Child reply content",
      reply_to_post_number: root_reply.post_number,
    )
  end

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
    cdp.allow_clipboard
  end

  describe "copy link on OP" do
    it "copies the nested URL" do
      nested_view.visit_nested(topic)
      nested_view.click_copy_link_on_op

      expected = "#{Discourse.base_url}/n/#{topic.slug}/#{topic.id}/#{op.post_number}"
      cdp.clipboard_has_text?(expected)
    end
  end

  describe "copy link on a nested post" do
    it "copies the nested URL" do
      nested_view.visit_nested(topic)
      nested_view.click_copy_link_on_post(root_reply)

      expected = "#{Discourse.base_url}/n/#{topic.slug}/#{topic.id}/#{root_reply.post_number}"
      cdp.clipboard_has_text?(expected)
    end
  end

  describe "copy link in context=0 view" do
    it "copies the standard nested URL without context param" do
      nested_view.visit_nested_context(topic, post_number: child_reply.post_number, context: 0)
      nested_view.click_copy_link_on_post(child_reply)

      expected = "#{Discourse.base_url}/n/#{topic.slug}/#{topic.id}/#{child_reply.post_number}"
      cdp.clipboard_has_text?(expected)
    end
  end
end
