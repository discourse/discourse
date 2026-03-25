# frozen_string_literal: true

RSpec.describe "View as nested button" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:nested_category) { Fabricate(:category, name: "Nested Category") }
  fab!(:topic) { Fabricate(:topic, user: user, category: category) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }
  fab!(:nested_topic) { Fabricate(:topic, user: user, category: nested_category) }
  fab!(:nested_op) { Fabricate(:post, topic: nested_topic, user: user, post_number: 1) }
  fab!(:nested_reply) do
    Fabricate(:post, topic: nested_topic, user: Fabricate(:user), raw: "A nested reply")
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    nested_category.category_setting.update!(nested_replies_default: true)
    NestedTopic.create!(topic: nested_topic)
    sign_in(user)
  end

  context "when nested_replies_show_view_as_nested_button is disabled" do
    before { SiteSetting.nested_replies_show_view_as_nested_button = false }

    it "does not show the link on a normal topic" do
      page.visit("/t/#{topic.slug}/#{topic.id}")

      expect(nested_view).to have_no_view_as_nested_link
    end

    it "still shows the link on a topic whose category defaults to nested" do
      page.visit("/t/#{nested_topic.slug}/#{nested_topic.id}?flat=1")

      expect(nested_view).to have_view_as_nested_link
    end

    it "still shows the link when topic has is_nested_view field" do
      NestedTopic.create!(topic: topic)

      page.visit("/t/#{topic.slug}/#{topic.id}?flat=1")

      expect(nested_view).to have_view_as_nested_link
    end
  end

  context "when nested_replies_show_view_as_nested_button is enabled" do
    before { SiteSetting.nested_replies_show_view_as_nested_button = true }

    it "shows the link on a normal topic" do
      page.visit("/t/#{topic.slug}/#{topic.id}")

      expect(nested_view).to have_view_as_nested_link
    end
  end
end
