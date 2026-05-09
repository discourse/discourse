# frozen_string_literal: true

module PageObjects
  module Pages
    class NestedView < PageObjects::Pages::Base
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
        has_css?("[data-post-number='#{post.post_number}'] .nested-post__expand-replies")
      end

      def has_no_replies_toggle_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'] .nested-post__expand-replies")
      end

      def has_no_show_replies_button_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'] .post-action-menu__show-replies")
      end

      def has_depth_line_for?(post)
        has_css?(wrapper_selector(post, ".nested-post__gutter .nested-post__depth-line"))
      end

      def has_no_depth_line_for?(post)
        has_no_css?(wrapper_selector(post, ".nested-post__gutter .nested-post__depth-line"))
      end

      def has_children_visible_for?(post)
        has_css?(wrapper_selector(post, ".nested-post-children"))
      end

      def has_no_children_visible_for?(post)
        has_no_css?(wrapper_selector(post, ".nested-post-children"))
      end

      def has_collapsed_bar_for?(post)
        has_css?(wrapper_selector(post, ".nested-post__collapsed-bar"))
      end

      def has_no_collapsed_bar_for?(post)
        has_no_css?(wrapper_selector(post, ".nested-post__collapsed-bar"))
      end

      def has_post_content_visible_for?(post)
        has_css?(wrapper_selector(post, ".nested-post__article"))
      end

      def has_no_post_content_visible_for?(post)
        has_no_css?(wrapper_selector(post, ".nested-post__article"))
      end

      def has_flat_view_link?
        has_css?(".nested-view__flat-link")
      end

      def has_no_flat_view_link?
        has_no_css?(".nested-view__flat-link")
      end

      def has_view_as_nested_link?
        has_css?(".nested-view-link")
      end

      def has_no_view_as_nested_link?
        has_no_css?(".nested-view-link")
      end

      def has_sort_active?(sort)
        has_css?(
          ".nested-sort-selector button.active",
          text: I18n.t("js.nested_replies.sort.#{sort}"),
        )
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
        find(wrapper_selector(post, ".nested-post__depth-line")).click
        self
      end

      def click_collapsed_bar(post)
        find(wrapper_selector(post, ".nested-post__collapsed-bar")).click
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
        find(".nested-sort-selector button", text: I18n.t("js.nested_replies.sort.#{sort}")).click
        self
      end

      # ── Deletion/recovery assertions ─────────────────────────────

      def has_deleted_placeholder_for?(post)
        has_css?("[data-post-number='#{post.post_number}'].nested-post__placeholder--deleted")
      end

      def has_no_deleted_placeholder_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'].nested-post__placeholder--deleted")
      end

      def has_deleted_post_class_for?(post)
        has_css?(".nested-post--deleted [data-post-number='#{post.post_number}']")
      end

      def has_toggle_deleted_content_button_for?(post)
        has_css?("[data-post-number='#{post.post_number}'] button.toggle-deleted-content")
      end

      def has_no_toggle_deleted_content_button_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'] button.toggle-deleted-content")
      end

      def click_toggle_deleted_content(post)
        find("[data-post-number='#{post.post_number}'] button.toggle-deleted-content").click
        self
      end

      def has_deleted_content_visible_for?(post)
        has_css?(wrapper_selector(post, ".nested-post__placeholder-reveal"))
      end

      def has_no_deleted_content_visible_for?(post)
        has_no_css?(wrapper_selector(post, ".nested-post__placeholder-reveal"))
      end

      # ── Ignored-user placeholder assertions ──────────────────────

      def has_ignored_placeholder_for?(post)
        has_css?("[data-post-number='#{post.post_number}'].nested-post__placeholder--ignored")
      end

      def has_no_ignored_placeholder_for?(post)
        has_no_css?("[data-post-number='#{post.post_number}'].nested-post__placeholder--ignored")
      end

      def click_reveal_ignored(post)
        find(
          "button.nested-post__placeholder-avatar--reveal[data-post-number='#{post.post_number}']",
        ).click
        self
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
        selector = "[data-post-number='#{post.post_number}']"
        if has_css?("#{selector} button.recover", wait: 5)
          find("#{selector} button.recover").click
        else
          within(selector) do
            find(".show-more-actions").click
            find("button.recover").click
          end
        end
        self
      end

      # ── Pinned post assertions ─────────────────────────────────

      def has_pinned_post?(post)
        has_css?(".nested-post--pinned [data-post-number='#{post.post_number}']")
      end

      def has_no_pinned_post?(post)
        has_no_css?(".nested-post--pinned [data-post-number='#{post.post_number}']")
      end

      # ── Load more ───────────────────────────────────────────────

      def has_load_more_roots_button?
        has_css?(".nested-view__load-more")
      end

      def click_load_more_roots
        find(".nested-view__load-more").click
        self
      end

      # ── Cloaking ─────────────────────────────────────────────────

      def has_cloaked_root?
        has_css?(".nested-view__roots > .nested-post--cloaked")
      end

      def has_no_cloaked_root?
        has_no_css?(".nested-view__roots > .nested-post--cloaked")
      end

      def has_cloaked_root_for?(post)
        has_css?(".nested-post--cloaked [data-post-number='#{post.post_number}']")
      end

      def has_uncloaked_root_for?(post)
        has_no_css?(".nested-post--cloaked [data-post-number='#{post.post_number}']") &&
          has_css?("[data-post-number='#{post.post_number}']")
      end

      # ── Suggested topics ──────────────────────────────────────────

      def has_suggested_topics?
        has_css?("#suggested-topics")
      end

      def has_no_suggested_topics?
        has_no_css?("#suggested-topics")
      end

      def has_suggested_topic?(topic)
        has_css?("#suggested-topics .topic-list-item[data-topic-id='#{topic.id}']")
      end

      private

      def post_container(post)
        find("[data-post-number='#{post.post_number}']")
      end

      def wrapper_selector(post, child_selector = nil)
        # Builds a CSS selector that targets the DIRECT .nested-post wrapper for
        # the given post, without storing any find() results. Uses > combinators
        # to avoid matching ancestor .nested-post wrappers in the nested tree.
        base = ".nested-post:has(> .nested-post__main > [data-post-number='#{post.post_number}'])"
        child_selector ? "#{base} #{child_selector}" : base
      end
    end
  end
end
