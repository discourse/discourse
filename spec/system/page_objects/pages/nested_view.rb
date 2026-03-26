# frozen_string_literal: true

module PageObjects
  module Pages
    class NestedView < PageObjects::Pages::Base
      SORT_LABELS = { "top" => "Top", "new" => "New", "old" => "Old" }.freeze

      def visit_nested(topic)
        page.visit("/n/#{topic.slug}/#{topic.id}")
        self
      end

      def visit_nested_context(topic, post_number:, context: nil)
        url = "/n/#{topic.slug}/#{topic.id}/#{post_number}"
        url += "?context=#{context}" if context
        page.visit(url)
        self
      end

      # ── Root view assertions ──────────────────────────────────────

      def has_nested_view?
        has_css?(".nested-view")
      end

      def has_no_nested_view?
        has_no_css?(".nested-view")
      end

      def has_root_post?(post)
        has_css?(".nested-view__roots [data-post-number='#{post.post_number}']")
      end

      def has_no_root_post?(post)
        has_no_css?(".nested-view__roots [data-post-number='#{post.post_number}']")
      end

      # ── Context view assertions ───────────────────────────────────

      def has_context_view?
        has_css?(".nested-context-view")
      end

      def has_view_full_thread_link?
        has_css?(".nested-context-view__full-thread")
      end

      def has_view_parent_context_link?
        has_css?(".nested-context-view__parent-context")
      end

      def has_no_view_parent_context_link?
        has_no_css?(".nested-context-view__parent-context")
      end

      # ── Post assertions ───────────────────────────────────────────

      def has_post_at_depth?(post, depth:)
        has_css?(".nested-post.--depth-#{depth} [data-post-number='#{post.post_number}']")
      end

      def has_post?(post)
        has_css?("[data-post-number='#{post.post_number}']")
      end

      def has_no_post?(post)
        has_no_css?("[data-post-number='#{post.post_number}']")
      end

      def has_continue_thread_for?(post)
        within(post_container(post)) { has_css?(".nested-post__continue-link") }
      end

      def has_no_continue_thread_for?(post)
        within(post_container(post)) { has_no_css?(".nested-post__continue-link") }
      end

      def has_highlighted_post?(post)
        has_css?(".nested-post--highlighted [data-post-number='#{post.post_number}']", wait: 5)
      end

      def has_reply_button_for?(post)
        has_css?("[data-post-number='#{post.post_number}'] .post-action-menu__reply")
      end

      def has_no_reply_button_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'] .post-action-menu__reply")
      end

      def has_like_button_for?(post)
        has_css?("[data-post-number='#{post.post_number}'] .post-action-menu__like")
      end

      def click_like_on_post(post)
        find("[data-post-number='#{post.post_number}'] .post-action-menu__like").click
      end

      def has_replies_toggle_for?(post)
        has_css?(
          "[data-post-number='#{post.post_number}'] .post-action-menu__nested-replies-expand",
        )
      end

      def has_no_replies_toggle_for?(post)
        has_no_css?(
          "[data-post-number='#{post.post_number}'] .post-action-menu__nested-replies-expand",
        )
      end

      def has_no_show_replies_button_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'] .post-action-menu__show-replies")
      end

      def has_depth_line_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.find(".nested-post__gutter", match: :first).has_css?(".nested-post__depth-line")
      end

      def has_no_depth_line_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.find(".nested-post__gutter", match: :first).has_no_css?(".nested-post__depth-line")
      end

      def has_children_visible_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_css?(".nested-post-children")
      end

      def has_no_children_visible_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_no_css?(".nested-post-children")
      end

      def has_collapsed_bar_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_css?(".nested-post__collapsed-bar")
      end

      def has_no_collapsed_bar_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_no_css?(".nested-post__collapsed-bar")
      end

      def has_post_content_visible_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_css?(".nested-post__article")
      end

      def has_no_post_content_visible_for?(post)
        wrapper = nested_post_wrapper(post)
        wrapper.has_no_css?(".nested-post__article")
      end

      def has_flat_view_link?
        has_css?(".nested-view__flat-link")
      end

      def has_view_as_nested_link?
        has_css?(".nested-view-link")
      end

      def has_no_view_as_nested_link?
        has_no_css?(".nested-view-link")
      end

      def has_sort_active?(sort)
        has_css?(".nested-sort-selector__option--active", text: SORT_LABELS[sort])
      end

      def has_op_post?
        has_css?(".nested-view__op")
      end

      def has_no_reply_button_on_op?
        has_no_css?(".nested-view__op .post-action-menu__reply")
      end

      def has_topic_title_editor?
        has_css?(".edit-topic-title")
      end

      def has_no_topic_title_editor?
        has_no_css?(".edit-topic-title")
      end

      def has_topic_map?
        has_css?(".nested-view__topic-map .topic-map__contents")
      end

      def has_no_top_replies_button?
        has_no_css?(".nested-view__topic-map .top-replies")
      end

      def has_floating_reply_button?
        has_css?(".nested-view__floating-actions:not(.--hidden) .nested-view__floating-reply")
      end

      def has_no_floating_reply_button?
        has_no_css?(".nested-view__floating-actions:not(.--hidden) .nested-view__floating-reply")
      end

      def has_floating_actions?
        has_css?(".nested-view__floating-actions:not(.--hidden)")
      end

      def has_no_floating_actions?
        has_no_css?(".nested-view__floating-actions:not(.--hidden)")
      end

      def has_notification_button?
        has_css?(".nested-view__floating-actions .topic-notifications-button")
      end

      def has_no_notification_button?
        has_no_css?(".nested-view__floating-actions .topic-notifications-button")
      end

      def has_admin_menu_button?
        has_css?(".nested-view__floating-actions .toggle-admin-menu")
      end

      def has_no_admin_menu_button?
        has_no_css?(".nested-view__floating-actions .toggle-admin-menu")
      end

      # ── Actions ───────────────────────────────────────────────────

      def click_edit_topic
        find(".nested-view__title .fancy-title").click
        self
      end

      def click_cancel_edit_topic
        find(".edit-topic-title .cancel-edit").click
        self
      end

      def click_save_edit_topic
        find(".edit-topic-title .submit-edit").click
        self
      end

      def fill_in_topic_title(title)
        find(".edit-topic-title input#edit-title").fill_in(with: title)
        self
      end

      def click_post_edit_button(post)
        within("[data-post-number='#{post.post_number}']") do
          find(".show-more-actions").click if has_css?(".show-more-actions", wait: 2)
          find("button.edit").click
        end
        self
      end

      def click_reply_on_post(post)
        find("[data-post-number='#{post.post_number}'] .post-action-menu__reply").click
        self
      end

      def click_reply_on_op
        find(".nested-view__op .post-action-menu__reply").click
        self
      end

      def click_continue_thread(post)
        within(post_container(post)) { find(".nested-post__continue-link").click }
        self
      end

      def click_depth_line(post)
        wrapper = nested_post_wrapper(post)
        wrapper.find(".nested-post__depth-line").click
        self
      end

      def click_collapsed_bar(post)
        wrapper = nested_post_wrapper(post)
        wrapper.find(".nested-post__collapsed-bar").click
        self
      end

      def click_view_full_thread
        find(".nested-context-view__full-thread").click
        self
      end

      def click_view_parent_context
        find(".nested-context-view__parent-context").click
        self
      end

      def click_floating_reply_button
        find(".nested-view__floating-reply").click
        self
      end

      def open_admin_menu
        find(".nested-view__floating-actions .toggle-admin-menu").click
        self
      end

      def click_admin_close_topic
        open_admin_menu
        find(".topic-admin-close .btn").click
        self
      end

      def click_admin_open_topic
        open_admin_menu
        find(".topic-admin-open .btn").click
        self
      end

      def change_notification_level(level)
        find(
          ".nested-view__floating-actions .topic-notifications-button .notifications-tracking-trigger-btn",
        ).click
        find(".notifications-tracking-btn[data-level-id='#{level}']").click
        self
      end

      def click_copy_link_on_op
        within(".nested-view__op") do
          find(".show-more-actions").click if has_css?(".show-more-actions", wait: 0)
          find("button.post-action-menu__copy-link").click
        end
        self
      end

      def click_copy_link_on_post(post)
        within("[data-post-number='#{post.post_number}']") do
          find(".show-more-actions").click if has_css?(".show-more-actions", wait: 0)
          find("button.post-action-menu__copy-link").click
        end
        self
      end

      def click_flat_view_link
        find(".nested-view__flat-link").click
        self
      end

      def click_sort(sort)
        find(".nested-sort-selector__option", text: SORT_LABELS[sort]).click
        self
      end

      # ── Deletion/recovery assertions ─────────────────────────────

      def has_deleted_placeholder_for?(post)
        has_css?("[data-post-number='#{post.post_number}'].nested-post__deleted-placeholder")
      end

      def has_no_deleted_placeholder_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'].nested-post__deleted-placeholder")
      end

      def has_deleted_post_class_for?(post)
        has_css?(".nested-post--deleted [data-post-number='#{post.post_number}']")
      end

      # ── Post actions ────────────────────────────────────────────

      def click_post_delete_button(post)
        within("[data-post-number='#{post.post_number}']") do
          find(".show-more-actions").click if has_css?(".show-more-actions", wait: 2)
          find("button.delete").click
        end
        self
      end

      def click_post_recover_button(post)
        within("[data-post-number='#{post.post_number}']") do
          find(".show-more-actions").click if has_css?(".show-more-actions", wait: 2)
          find("button.recover").click
        end
        self
      end

      # ── Load more ───────────────────────────────────────────────

      def has_load_more_roots_button?
        has_css?(".nested-view__load-more")
      end

      def click_load_more_roots
        find(".nested-view__load-more").click
        self
      end

      def root_post_count
        all(".nested-view__roots > .nested-post").count
      end

      # ── Cloaking ─────────────────────────────────────────────────

      def has_cloaked_root?
        has_css?(".nested-view__roots > .nested-post--cloaked")
      end

      def has_no_cloaked_root?
        has_no_css?(".nested-view__roots > .nested-post--cloaked")
      end

      def has_cloaked_root_for?(post)
        root = nested_post_wrapper(post)
        root[:class].include?("nested-post--cloaked")
      end

      def has_uncloaked_root_for?(post)
        root = nested_post_wrapper(post)
        !root[:class].include?("nested-post--cloaked")
      end

      # ── Post counting ─────────────────────────────────────────────

      def posts_at_depth(depth)
        all(".nested-post.--depth-#{depth} .nested-post__article")
      end

      private

      def post_container(post)
        find("[data-post-number='#{post.post_number}']")
      end

      def nested_post_wrapper(post)
        find("[data-post-number='#{post.post_number}']").find(
          :xpath,
          "ancestor::div[contains(concat(' ', @class, ' '), ' nested-post ')][1]",
        )
      end
    end
  end
end
