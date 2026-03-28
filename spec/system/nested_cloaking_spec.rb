# frozen_string_literal: true

RSpec.describe "Nested view cloaking" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
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

      first_root = all(".nested-view__roots > .nested-post").first
      expect(first_root[:class]).not_to include("nested-post--cloaked")
    end

    it "uncloaks roots when scrolling to them" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      send_keys(:end)

      expect(page).to have_css(
        ".nested-view__roots > .nested-post:first-child.nested-post--cloaked",
        wait: 5,
      )

      send_keys(:home)

      first_root = find(".nested-view__roots > .nested-post:first-child")
      expect(first_root[:class]).not_to include("nested-post--cloaked")
    end

    it "hides children content when root is cloaked" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      cloaked = find(".nested-view__roots > .nested-post--cloaked", match: :first)
      expect(cloaked).to have_no_css(".nested-post__article")
      expect(cloaked).to have_no_css(".nested-post-children")
    end
  end
end
