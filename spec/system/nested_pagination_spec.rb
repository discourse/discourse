# frozen_string_literal: true

RSpec.describe "Nested view pagination" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(user)
  end

  describe "load more children" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root post with many children")
    end

    # Create 5 child replies — initial load preloads 3, so "load more" appears
    fab!(:child_1) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply one",
        reply_to_post_number: root_reply.post_number,
        created_at: 5.minutes.ago,
      )
    end

    fab!(:child_2) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply two",
        reply_to_post_number: root_reply.post_number,
        created_at: 4.minutes.ago,
      )
    end

    fab!(:child_3) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply three",
        reply_to_post_number: root_reply.post_number,
        created_at: 3.minutes.ago,
      )
    end

    fab!(:child_4) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply four",
        reply_to_post_number: root_reply.post_number,
        created_at: 2.minutes.ago,
      )
    end

    fab!(:child_5) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply five",
        reply_to_post_number: root_reply.post_number,
        created_at: 1.minute.ago,
      )
    end

    it "shows load more button and loads additional children on click" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_post(root_reply)
      expect(
        browser_root.locator(".nested-post-children__load-more").filter(visible: true),
      ).not_to have_count(0)

      browser_root.locator(".nested-post-children__load-more").filter(visible: true).click

      expect(nested_view).to have_post(child_1)
      expect(nested_view).to have_post(child_2)
      expect(nested_view).to have_post(child_3)
      expect(nested_view).to have_post(child_4)
      expect(nested_view).to have_post(child_5)
      expect(
        browser_root.locator(".nested-post-children__load-more").filter(visible: true),
      ).to have_count(0)
    end
  end

  describe "load more roots" do
    # ROOTS_PER_PAGE is 20, so create 22 to have pagination
    before do
      22.times do |i|
        Fabricate(
          :post,
          topic: topic,
          user: Fabricate(:user),
          raw: "Root post number #{i + 1}",
          reply_to_post_number: nil,
        )
      end
    end

    it "initially shows first page of roots and loads more on scroll" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_nested_view
      initial_count =
        browser_root
          .locator(".nested-view__roots > .nested-post")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .count
      expect(initial_count).to eq(20)

      browser_page.evaluate(
        "function(arguments) { window.scrollTo(0, document.body.scrollHeight) }",
        arg: [],
      )

      expect(
        browser_root.locator(".nested-view__roots > .nested-post").filter(visible: true),
      ).to have_count(22, timeout: 5 * 1000)
    end
  end
end
