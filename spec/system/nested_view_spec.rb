# frozen_string_literal: true

require_relative "../support/nested_replies_helpers"

RSpec.describe "Nested view" do
  include NestedRepliesHelpers

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:nested_topic_record) { Fabricate(:nested_topic, topic: topic) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  describe "basic rendering" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply") }
    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply",
        reply_to_post_number: root_reply.post_number,
      )
    end

    it "displays the nested view with root posts" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)
    end

    it "does not show the standard replies button in nested post menus" do
      root_reply.update!(reply_count: 1)
      nested_view.visit_nested(topic)

      expect(nested_view).to have_no_show_replies_button_for(op)
      expect(nested_view).to have_no_show_replies_button_for(root_reply)
    end

    it "shows the original post content" do
      op.update!(raw: "This is the original post content")
      op.rebake!

      nested_view.visit_nested(topic)

      expect(nested_view).to have_op_post
      expect(browser_root.locator(".nested-view__op").filter(visible: true)).to contain_text(
        [browser_text_pattern("This is the original post content")],
        useInnerText: true,
      )
    end
  end

  describe "topic list navigation" do
    fab!(:root_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Root reply\n\n#{("Scrollable root reply content.\n\n" * 30).strip}",
      )
    end

    it "lets the user reopen a nested topic after going back to the list" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_topic(topic)

      topic_list.visit_topic(topic)
      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}})
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)

      browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_topic(topic)

      topic_list.visit_topic(topic)
      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}})
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)
    end

    it "returns the user to their previous position with browser forward" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_topic(topic)

      topic_list.visit_topic(topic)
      expect(nested_view).to have_nested_view

      nested_view.scroll_post_near_top(root_reply)
      previous_scroll_y =
        browser_page.evaluate("function(arguments) { return window.scrollY }", arg: [])

      browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_topic(topic)

      browser_page.go_forward.tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(nested_view).to have_nested_view
      try_until_success(reason: "nested topic cache restores after browser forward") do
        expect(
          browser_page.evaluate("function(arguments) { return window.scrollY }", arg: []),
        ).to be_within(250).of(previous_scroll_y)
      end
    end
  end

  describe "topic map" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }

    it "displays the topic map" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_topic_map
    end

    it "hides the top replies button" do
      topic.update!(has_summary: true)

      nested_view.visit_nested(topic)

      expect(nested_view).to have_topic_map
      expect(nested_view).to have_no_top_replies_button
    end

    it "lets users access topic actions before sorting replies" do
      reader = Fabricate(:user, refresh_auto_groups: true)
      sign_in(reader)

      nested_view.visit_nested(topic)

      expect(nested_view).to have_topic_actions_above_controls
      expect(nested_view).to have_share_topic_action
      expect(nested_view).to have_bookmark_topic_action
      expect(nested_view).to have_flag_topic_action
      expect(nested_view).to have_no_topic_action_reply_button
    end
  end

  describe "topic title editing" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }

    before { sign_in(admin) }

    it "shows the topic title editor when clicking the title" do
      nested_view.visit_nested(topic)

      nested_view.click_edit_topic
      expect(nested_view).to have_topic_title_editor
    end

    it "cancels topic title editing" do
      nested_view.visit_nested(topic)

      nested_view.click_edit_topic
      expect(nested_view).to have_topic_title_editor

      nested_view.click_cancel_edit_topic
      expect(nested_view).to have_no_topic_title_editor
    end

    it "saves edited topic title" do
      nested_view.visit_nested(topic)

      nested_view.click_edit_topic
      nested_view.fill_in_topic_title("Updated Topic Title")
      nested_view.click_save_edit_topic

      expect(nested_view).to have_no_topic_title_editor
      expect(browser_root.locator(".nested-view__title").filter(visible: true)).to contain_text(
        [browser_text_pattern("Updated Topic Title")],
        useInnerText: true,
      )
    end
  end

  describe "topic header" do
    fab!(:scrollable_replies) do
      Fabricate.times(8, :post, topic: topic, user: user, raw: "Scrollable nested reply\n\n" * 30)
    end

    it "shows the topic title after scrolling past it" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_no_topic_title_in_site_header(topic)

      nested_view.scroll_past_topic_title

      expect(nested_view).to have_topic_title_in_site_header(topic)
    end
  end

  describe "post editing" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: user, raw: "My editable reply") }

    let(:composer) { PageObjects::Components::Composer.new }

    it "opens the composer in edit mode" do
      nested_view.visit_nested(topic)

      nested_view.click_post_edit_button(root_reply)
      expect(composer).to be_opened
      expect(composer).to have_displayed_content("My editable reply")
    end

    it "opens the composer when editing the OP" do
      op.update!(raw: "Original post content that is long enough")
      op.rebake!

      nested_view.visit_nested(topic)

      nested_view.click_post_edit_button(op)
      expect(composer).to be_opened
      expect(composer).to have_displayed_content("Original post content that is long enough")
    end
  end

  describe "empty topic" do
    it "shows 'no replies' message when topic has no replies" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_nested_view
      expect(browser_root.locator(".nested-view__empty").filter(visible: true)).to contain_text(
        [browser_text_pattern("No replies yet.")],
        useInnerText: true,
      )
    end
  end

  describe "sorting" do
    fab!(:old_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Older reply",
        created_at: 2.days.ago,
      )
    end

    fab!(:new_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Newer reply",
        created_at: 1.minute.ago,
      )
    end

    it "changes sort order and updates the URL" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_sort_active("top")

      nested_view.click_sort("new")
      expect(nested_view).to have_sort_active("new")
      expect(browser_page).to have_url(/sort=new/)

      nested_view.click_sort("old")
      expect(nested_view).to have_sort_active("old")
      expect(browser_page).to have_url(/sort=old/)
    end

    it "shows hot sorting only while its rollout gate is enabled" do
      nested_view.visit_nested(topic)
      browser_root.locator(".nested-sort-selector__trigger").filter(visible: true).click

      expect(browser_root.locator(".dropdown-menu .btn").filter(visible: true)).not_to contain_text(
        [browser_text_pattern(I18n.t("js.nested_replies.sort.hot"))],
        useInnerText: true,
      )

      SiteSetting.nested_replies_hot_sort_enabled = true
      nested_view.visit_nested(topic)
      nested_view.click_sort("hot")

      expect(nested_view).to have_sort_active("hot")
      expect(browser_page).to have_url(/sort=hot/)
    end
  end

  describe "expand and collapse" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Post with children")
    end

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A child post",
        reply_to_post_number: root_reply.post_number,
      )
    end

    it "collapses post content and children when clicking the depth line" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_post(child_reply)
      expect(nested_view).to have_children_visible_for(root_reply)
      expect(nested_view).to have_no_collapsed_bar_for(root_reply)

      nested_view.click_depth_line(root_reply)
      expect(nested_view).to have_collapsed_bar_for(root_reply)
      expect(nested_view).to have_no_post_content_visible_for(root_reply)
      expect(nested_view).to have_no_children_visible_for(root_reply)
    end

    it "re-expands post content and children when clicking the collapsed bar" do
      nested_view.visit_nested(topic)

      nested_view.click_depth_line(root_reply)
      expect(nested_view).to have_collapsed_bar_for(root_reply)

      nested_view.click_collapsed_bar(root_reply)
      expect(nested_view).to have_no_collapsed_bar_for(root_reply)
      expect(nested_view).to have_post_content_visible_for(root_reply)
      expect(nested_view).to have_children_visible_for(root_reply)
      expect(nested_view).to have_post(child_reply)
    end
  end

  describe "mobile focused branch navigation" do
    before { SiteSetting.nested_replies_max_depth = 10 }

    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Post with children")
    end

    fab!(:sibling_root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Sibling root reply")
    end

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A child post",
        reply_to_post_number: root_reply.post_number,
      )
    end

    fab!(:grandchild_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A grandchild post",
        reply_to_post_number: child_reply.post_number,
      )
    end

    fab!(:great_grandchild_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A great-grandchild post",
        reply_to_post_number: grandchild_reply.post_number,
      )
    end

    fab!(:fifth_level_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A fifth-level post",
        reply_to_post_number: great_grandchild_reply.post_number,
      )
    end

    fab!(:sixth_level_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "A sixth-level post",
        reply_to_post_number: fifth_level_reply.post_number,
      )
    end

    it "lets the user drill into reply branches without leaving the topic", mobile: true do
      nested_view.visit_nested(topic)
      nested_path = %r{/t/#{topic.slug}/#{topic.id}}

      expect(nested_view).to have_post(child_reply)
      expect(nested_view).to have_post(grandchild_reply)
      expect(nested_view).to have_post(great_grandchild_reply)
      expect(nested_view).to have_replies_toggle_for(great_grandchild_reply)
      expect(nested_view).to have_no_post(fifth_level_reply)

      nested_view.click_replies_toggle(great_grandchild_reply)

      expect(browser_page).to have_url(
        %r{/t/#{topic.slug}/#{topic.id}/#{great_grandchild_reply.post_number}},
      )
      expect(nested_view).to have_mobile_focus
      expect(nested_view).to have_mobile_ancestor(root_reply)
      expect(nested_view).to have_mobile_ancestor(child_reply)
      expect(nested_view).to have_mobile_ancestor(grandchild_reply)
      expect(nested_view).to have_post(fifth_level_reply)
      expect(nested_view).to have_post(sixth_level_reply)
      expect(nested_view).to have_no_root_post(sibling_root_reply)

      nested_view.click_mobile_focus_back

      expect(browser_page).to have_url(nested_path)
      expect(nested_view).to have_no_mobile_focus
      expect(nested_view).to have_root_post(sibling_root_reply)
    end

    it "browser back returns from a focused branch to the full nested topic and restores scroll",
       mobile: true do
      child_reply.update!(raw: "A child post\n\n#{("Scrollable child content.\n\n" * 30).strip}")
      child_reply.rebake!

      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      nested_view.visit_nested(topic)
      nested_view.scroll_post_near_top(great_grandchild_reply)

      previous_scroll_y = nested_view.trigger_replies_toggle(great_grandchild_reply)
      expect(browser_page).to have_url(
        %r{/t/#{topic.slug}/#{topic.id}/#{great_grandchild_reply.post_number}},
      )
      expect(nested_view).to have_mobile_focus

      browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}$})
      expect(nested_view).to have_no_mobile_focus
      try_until_success(reason: "scroll anchor restores after focused view closes") do
        expect(
          browser_page.evaluate("function(arguments) { return window.scrollY }", arg: []),
        ).to be_within(250).of(previous_scroll_y)
      end
    end

    it "uses the focused branch UI for direct post URLs", mobile: true do
      nested_view.visit_nested_context(topic, post_number: grandchild_reply.post_number)

      expect(browser_page).to have_url(
        %r{/t/#{topic.slug}/#{topic.id}/#{grandchild_reply.post_number}},
      )
      expect(nested_view).to have_mobile_focus
      expect(nested_view).to have_mobile_ancestor(root_reply)
      expect(nested_view).to have_mobile_ancestor(child_reply)
      expect(nested_view).to have_post(great_grandchild_reply)

      nested_view.click_mobile_ancestor(child_reply)

      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}/#{child_reply.post_number}})
      expect(nested_view).to have_mobile_ancestor(root_reply)
      expect(nested_view).to have_no_mobile_ancestor(child_reply)
    end

    it "returns from direct post URLs to all replies", mobile: true do
      nested_view.visit_nested_context(topic, post_number: grandchild_reply.post_number)

      expect(nested_view).to have_mobile_focus

      nested_view.click_mobile_focus_back

      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}(?:\?.*)?$})
      expect(nested_view).to have_no_mobile_focus
      expect(nested_view).to have_root_post(root_reply)
      expect(nested_view).to have_root_post(sibling_root_reply)
    end

    it "does not open the user card when tapping a focused path avatar", mobile: true do
      nested_view.visit_nested_context(topic, post_number: grandchild_reply.post_number)

      expect(nested_view).to have_mobile_ancestor(child_reply)
      expect(nested_view).to have_no_mobile_ancestor_user_card_trigger(child_reply)

      nested_view.click_mobile_ancestor_avatar(child_reply)

      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}/#{child_reply.post_number}})
      expect(nested_view).to have_no_mobile_ancestor(child_reply)
      expect(browser_root.locator(".user-card.show").filter(visible: true)).to have_count(0)
    end

    it "brings the parent branch control into view after opening hidden replies", mobile: true do
      sixth_level_reply.update!(
        raw: "A sixth-level post\n\n#{("More focused branch content.\n\n" * 30).strip}",
      )
      sixth_level_reply.rebake!

      nested_view.visit_nested(topic)
      nested_view.scroll_post_near_top(great_grandchild_reply)

      nested_view.click_replies_toggle(great_grandchild_reply)

      expect(nested_view).to have_mobile_focus
      try_until_success(reason: "focused view scroll runs after render") do
        expect(nested_view.mobile_ancestor_viewport_top(grandchild_reply)).to be_between(
          -1,
          120,
        ).inclusive
      end
    end

    it "collapses a root branch from the depth line", mobile: true do
      nested_view.visit_nested(topic)

      nested_view.click_depth_line(root_reply)

      expect(nested_view).to have_no_mobile_focus
      expect(nested_view).to have_collapsed_bar_for(root_reply)
      expect(nested_view).to have_no_children_visible_for(root_reply)
      expect(nested_view).to have_root_post(sibling_root_reply)
    end

    it "collapses a child branch from the depth line", mobile: true do
      nested_view.visit_nested(topic)

      nested_view.click_depth_line(child_reply)

      expect(nested_view).to have_no_mobile_focus
      expect(nested_view).to have_collapsed_bar_for(child_reply)
      expect(nested_view).to have_no_children_visible_for(child_reply)
      expect(nested_view).to have_root_post(sibling_root_reply)
    end

    it "collapses a branch with hidden replies from the depth line", mobile: true do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_replies_toggle_for(great_grandchild_reply)
      expect(nested_view).to have_no_post(fifth_level_reply)

      nested_view.click_depth_line(great_grandchild_reply)

      expect(nested_view).to have_no_mobile_focus
      expect(nested_view).to have_collapsed_bar_for(great_grandchild_reply)
      expect(nested_view).to have_no_post(fifth_level_reply)
      expect(nested_view).to have_root_post(sibling_root_reply)
    end
  end

  describe "routing" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }

    it "direct URL loads correctly" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)
      expect(browser_page).to have_url(%r{/t/#{topic.slug}/#{topic.id}})
    end

    it "direct URL with post_number loads context view" do
      chain = create_reply_chain(depth: 3)

      nested_view.visit_nested_context(topic, post_number: chain[1].post_number)

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(chain[1])
    end
  end

  describe "anonymous access" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Public reply")
    end

    before { reset_browser_sessions }

    it "allows anonymous users to view the nested view" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)
      expect(nested_view).to have_op_post
    end

    it "shows login reply only in floating actions for anonymous users" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_no_reply_button_for(root_reply)
      expect(nested_view).to have_no_reply_button_on_op
      expect(nested_view).to have_floating_reply_button
    end

    it "shows login page when anonymous user clicks like" do
      nested_view.visit_nested(topic)
      nested_view.click_like_on_post(root_reply)

      expect(browser_root.locator(".login-fullpage").filter(visible: true)).not_to have_count(0)
    end
  end

  describe "suggested topics" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }
    fab!(:other_topic) { Fabricate(:post).topic }

    it "renders suggested topics at the end of the nested view" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_suggested_topics
      expect(nested_view).to have_suggested_topic(other_topic)
    end
  end

  describe "plugin disabled" do
    it "renders the flat topic route when nested replies are disabled" do
      SiteSetting.nested_replies_enabled = false

      nested_view.visit_nested(topic)

      expect(nested_view).to have_no_nested_view
      expect(browser_root.locator("#post_1").filter(visible: true)).not_to have_count(0)
    end
  end
end
