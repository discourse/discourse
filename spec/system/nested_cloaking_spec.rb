# frozen_string_literal: true

RSpec.describe "Nested view cloaking" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(user)
  end

  context "with many root posts" do
    before do
      20.times do |i|
        root =
          Fabricate(
            :post,
            topic: topic,
            user: Fabricate(:user),
            raw: "Root post number #{i + 1} with enough content to take up space",
          )
        Fabricate(
          :post,
          topic: topic,
          user: Fabricate(:user),
          raw: "Child reply to root #{i + 1}",
          reply_to_post_number: root.post_number,
        )
      end
    end

    it "cloaks root subtrees far from the viewport" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      expect(nested_view).to have_cloaked_root

      expect(
        browser_root.locator(
          ".nested-view__roots > .nested-post:first-child.nested-post--cloaked",
        ).filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "uncloaks roots when scrolling to them" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      browser_page.keyboard.press("End")

      expect(
        browser_root.locator(
          ".nested-view__roots > .nested-post:first-child.nested-post--cloaked",
        ).filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0, timeout: 5 * 1000)

      browser_page.keyboard.press("Home")

      expect(
        browser_root.locator(
          ".nested-view__roots > .nested-post:first-child.nested-post--cloaked",
        ).filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "hides children content when root is cloaked" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      expect(
        browser_root.locator(
          ".nested-view__roots > .nested-post--cloaked .nested-post__article",
        ).filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(
          ".nested-view__roots > .nested-post--cloaked .nested-post-children",
        ).filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end
  end
end
