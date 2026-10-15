# frozen_string_literal: true

module PageObjects
  module Pages
    class NestedView < PageObjects::Pages::Base
      def visit_nested(topic, query: nil)
        url = "/t/#{topic.slug}/#{topic.id}"
        url += "?#{query}" if query
        browser_page.goto(url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_nested_context(topic, post_number:, context: nil)
        url = "/t/#{topic.slug}/#{topic.id}/#{post_number}"
        url += "?context=#{context}" if context
        browser_page.goto(url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def reload_with_pending_pagination
        # Capybara's refresh waits for AJAX to settle, but pagination is intentionally held open.
        browser_page.reload
        self
      end

      # In-app navigation via DiscourseURL.routeTo — exercises the same
      # routing code path a notification or in-page link click would,
      # rather than doing a full page reload like visit_nested_context.
      # Use this when the test needs to verify behavior that depends on
      # the existing nested controller/components staying mounted across
      # the transition.
      def route_to(path)
        browser_page.evaluate(
          "function(arguments) { #{%(require("discourse/lib/url").default.routeTo(#{path.to_json});)} }",
          arg: [],
        )
        self
      end

      def route_to_nested_context(topic, post_number:, query: nil)
        path = "/t/#{topic.slug}/#{topic.id}/#{post_number}"
        path += "?#{query}" if query
        route_to(path)
      end

      def route_to_topic_post(topic, post_number:)
        route_to("/t/#{topic.slug}/#{topic.id}/#{post_number}")
      end

      # ── Root view assertions ──────────────────────────────────────

      def has_nested_view?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view").filter(visible: true),
        )
      end

      def has_no_nested_view?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view").filter(visible: true),
        )
      end

      def has_root_post?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-view__roots [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_no_root_post?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".nested-view__roots [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      # ── Context view assertions ───────────────────────────────────

      def has_context_view?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-context-view").filter(visible: true),
        )
      end

      def has_no_context_view?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-context-view").filter(visible: true),
        )
      end

      def has_context_banner?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.nested_replies.context.banner"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".nested-context-view__banner").filter(visible: true))
      end

      def has_no_context_banner?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-context-view__banner").filter(visible: true),
        )
      end

      def has_view_full_thread_link?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-context-view__full-thread").filter(visible: true),
        )
      end

      def has_view_parent_context_link?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-context-view__parent-context").filter(visible: true),
        )
      end

      def has_no_view_parent_context_link?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-context-view__parent-context").filter(visible: true),
        )
      end

      # ── Post assertions ───────────────────────────────────────────

      def has_post_at_depth?(post, depth:)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-post.--depth-#{depth} [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_post?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
        )
      end

      def has_post_text?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".nested-post__article").filter(visible: true),
        )
      end

      def has_no_post?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
        )
      end

      def has_continue_thread_for?(post)
        within_browser(post_container(post)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".nested-post__continue-link").filter(visible: true),
          )
        end
      end

      def has_no_continue_thread_for?(post)
        within_browser(post_container(post)) do
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".nested-post__continue-link").filter(visible: true),
          )
        end
      end

      def has_highlighted_post?(post)
        PlaywrightMatchers.have_count(0, timeout: 5 * 1000).does_not_match?(
          browser_root.locator(
            ".nested-post--highlighted [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_reply_button_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .post-action-menu__reply",
          ).filter(visible: true),
        )
      end

      def has_no_reply_button_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .post-action-menu__reply",
          ).filter(visible: true),
        )
      end

      def has_like_button_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .post-action-menu__like",
          ).filter(visible: true),
        )
      end

      def click_like_on_post(post)
        browser_root
          .locator("[data-post-number='#{post.post_number}'] .post-action-menu__like")
          .filter(visible: true)
          .click
      end

      def has_replies_toggle_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .nested-post__expand-replies",
          ).filter(visible: true),
        )
      end

      def has_no_replies_toggle_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .nested-post__expand-replies",
          ).filter(visible: true),
        )
      end

      def has_load_more_children_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            wrapper_selector(
              post,
              "> .nested-post__main > .nested-post-children .nested-post-children__load-more",
            ),
          ).filter(visible: true),
        )
      end

      def has_no_show_replies_button_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] .post-action-menu__show-replies",
          ).filter(visible: true),
        )
      end

      def has_mobile_focus?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__mobile-focus").filter(visible: true),
        )
      end

      def has_no_mobile_focus?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__mobile-focus").filter(visible: true),
        )
      end

      def has_mobile_ancestor?(post)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(post.user.username)],
          useInnerText: true,
        ).matches?(
          browser_root.locator("[data-test-nested-mobile-ancestor='#{post.post_number}']").filter(
            visible: true,
          ),
        )
      end

      def has_no_mobile_ancestor?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-nested-mobile-ancestor='#{post.post_number}']").filter(
            visible: true,
          ),
        )
      end

      def has_no_mobile_ancestor_user_card_trigger?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-test-nested-mobile-ancestor='#{post.post_number}'] [data-user-card]",
          ).filter(visible: true),
        )
      end

      def post_viewport_top(post)
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          document
            .querySelector("[data-post-number='#{post.post_number}']")
            .closest(".nested-post")
            .getBoundingClientRect()
            .top
        JS
      end

      def mobile_ancestor_viewport_top(post)
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          document
            .querySelector("[data-test-nested-mobile-ancestor='#{post.post_number}']")
            .getBoundingClientRect()
            .top
        JS
      end

      def has_depth_line_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(depth_line_selector(post)).filter(visible: true),
        )
      end

      def has_no_depth_line_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(depth_line_selector(post)).filter(visible: true),
        )
      end

      def has_leaf_depth_line_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(leaf_depth_line_selector(post)).filter(visible: true),
        )
      end

      def has_no_leaf_depth_line_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(leaf_depth_line_selector(post)).filter(visible: true),
        )
      end

      def has_children_visible_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post-children"),
          ).filter(visible: true),
        )
      end

      def has_no_children_visible_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post-children"),
          ).filter(visible: true),
        )
      end

      def has_collapsed_bar_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post__collapsed-bar"),
          ).filter(visible: true),
        )
      end

      def has_no_collapsed_bar_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post__collapsed-bar"),
          ).filter(visible: true),
        )
      end

      def has_post_content_visible_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post__article"),
          ).filter(visible: true),
        )
      end

      def has_no_post_content_visible_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            wrapper_selector(post, "> .nested-post__main > .nested-post__article"),
          ).filter(visible: true),
        )
      end

      def has_sort_active?(sort)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.nested_replies.sort.#{sort}"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".nested-sort-selector__trigger").filter(visible: true))
      end

      def has_root_post_count?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".nested-view__roots > .nested-post").filter(visible: true),
        )
      end

      def current_scroll_position
        browser_page.evaluate("function(arguments) { return window.scrollY }", arg: [])
      end

      def with_root_pagination_paused(topic, &block)
        pattern = %r{/n/#{Regexp.escape(topic.slug)}/#{topic.id}\.json\?.*\bpage=1(?:&|$)}
        PageObjects::CDP.new.with_paused_request(pattern, &block)
      end

      def disable_cloaking
        browser_page.evaluate(
          "function(arguments) { require(\"discourse/modifiers/post-stream-viewport-tracker\").disableCloaking() }",
          arg: [],
        )
        self
      end

      def scroll_to_bottom
        browser_page.evaluate(
          "function(arguments) { window.scrollTo(0, document.body.scrollHeight) }",
          arg: [],
        )
        self
      end

      def user_scroll_by(distance:)
        start_position = current_scroll_position

        browser_page.then do |playwright_page|
          viewport = playwright_page.viewport_size
          playwright_page.mouse.move(viewport[:width] * 0.65, viewport[:height] * 0.5)
          playwright_page.mouse.wheel(0, distance)
        end

        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            <<~JS
          const [startPosition, done] = arguments;
          let previousPosition;
          let stableFrames = 0;

          const finishWhenStable = () => {
            const currentPosition = window.scrollY;
            const hasMoved = currentPosition !== startPosition;
            stableFrames =
              hasMoved && currentPosition === previousPosition
                ? stableFrames + 1
                : 0;
            previousPosition = currentPosition;

            if (stableFrames === 2) {
              done(currentPosition);
            } else {
              requestAnimationFrame(finishWhenStable);
            }
          };

          requestAnimationFrame(finishWhenStable);
        JS
          } }).apply(this, args); }); }",
          arg: browser_arguments(start_position),
        )
      end

      def centered_root_post_number
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          (() => {
            const roots = document.querySelector(".nested-view__roots");
            const rootsRect = roots.getBoundingClientRect();
            const element = document.elementFromPoint(
              rootsRect.left + rootsRect.width / 2,
              window.innerHeight / 2
            );
            const root = element?.closest(".nested-post");
            const article = root?.querySelector(
              ":scope > .nested-post__main > [data-post-number]"
            );

            return Number(article?.dataset.postNumber);
          })()
        JS
      end

      def scroll_to_post(post)
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
          document.querySelector("[data-post-number='#{post.post_number}']").scrollIntoView();
        JS
        self
      end

      def has_op_post?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__op").filter(visible: true),
        )
      end

      def has_no_reply_button_on_op?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__op .post-action-menu__reply").filter(visible: true),
        )
      end

      def has_topic_title_editor?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".edit-topic-title").filter(visible: true),
        )
      end

      def has_no_topic_title_editor?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".edit-topic-title").filter(visible: true),
        )
      end

      def has_topic_title_in_site_header?(topic)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(topic.title)],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            "header.d-header .header-title .topic-link[data-topic-id='#{topic.id}']",
          ).filter(visible: true),
        )
      end

      def has_no_topic_title_in_site_header?(topic)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(topic.title)],
          useInnerText: true,
        ).does_not_match?(
          browser_root.locator(
            "header.d-header .header-title .topic-link[data-topic-id='#{topic.id}']",
          ).filter(visible: true),
        )
      end

      def has_topic_map?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-view__op > .nested-view__topic-map .topic-map__contents",
          ).filter(visible: true),
        )
      end

      def has_no_top_replies_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__op > .nested-view__topic-map .top-replies").filter(
            visible: true,
          ),
        )
      end

      def has_topic_actions_above_controls?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__topic-actions + .nested-view__controls").filter(
            visible: true,
          ),
        )
      end

      def has_activity_log_link?
        PlaywrightMatchers.have_count(0, timeout: 10 * 1000).does_not_match?(
          browser_root.locator(".nested-view__activity-link").filter(visible: true),
        )
      end

      def has_no_activity_log_link?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__activity-link").filter(visible: true),
        )
      end

      def has_share_topic_action?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-view__topic-actions #topic-footer-button-share-and-invite",
          ).filter(visible: true),
        )
      end

      def has_bookmark_topic_action?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__topic-actions .bookmark-menu__trigger").filter(
            visible: true,
          ),
        )
      end

      def has_flag_topic_action?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__topic-actions #topic-footer-button-flag").filter(
            visible: true,
          ),
        )
      end

      def has_no_topic_action_reply_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__topic-actions .create").filter(visible: true),
        )
      end

      def has_floating_reply_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-view__floating-actions:not(.--hidden) .nested-view__floating-reply",
          ).filter(visible: true),
        )
      end

      def has_no_floating_reply_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".nested-view__floating-actions:not(.--hidden) .nested-view__floating-reply",
          ).filter(visible: true),
        )
      end

      def has_floating_actions?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__floating-actions:not(.--hidden)").filter(
            visible: true,
          ),
        )
      end

      def has_no_floating_actions?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__floating-actions:not(.--hidden)").filter(
            visible: true,
          ),
        )
      end

      def has_notification_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__floating-actions .topic-notifications-button").filter(
            visible: true,
          ),
        )
      end

      def has_no_notification_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__floating-actions .topic-notifications-button").filter(
            visible: true,
          ),
        )
      end

      def has_admin_menu_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__floating-actions .toggle-admin-menu").filter(
            visible: true,
          ),
        )
      end

      def has_no_admin_menu_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__floating-actions .toggle-admin-menu").filter(
            visible: true,
          ),
        )
      end

      # ── Actions ───────────────────────────────────────────────────

      def click_edit_topic
        browser_root.locator(".nested-view__title .fancy-title").filter(visible: true).click
        self
      end

      def open_activity_log
        browser_root.locator(".nested-view__activity-link").filter(visible: true).click
        self
      end

      def click_cancel_edit_topic
        browser_root.locator(".edit-topic-title .cancel-edit").filter(visible: true).click
        self
      end

      def click_save_edit_topic
        browser_root.locator(".edit-topic-title .submit-edit").filter(visible: true).click
        self
      end

      def fill_in_topic_title(title)
        browser_root.locator(".edit-topic-title input#edit-title").filter(visible: true).fill(title)
        self
      end

      def click_post_edit_button(post)
        within_browser(
          browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
        ) do
          if PlaywrightMatchers.have_count(0, timeout: 2 * 1000).does_not_match?(
               browser_root.locator(".show-more-actions").filter(visible: true),
             )
            browser_root.locator(".show-more-actions").filter(visible: true).click
          end
          browser_root.locator("button.edit").filter(visible: true).click
        end
        self
      end

      def click_view_full_thread
        browser_root.locator(".nested-context-view__full-thread").filter(visible: true).click
        self
      end

      def click_view_parent_context
        browser_root.locator(".nested-context-view__parent-context").filter(visible: true).click
        self
      end

      def click_reply_on_post(post)
        browser_root
          .locator("[data-post-number='#{post.post_number}'] .post-action-menu__reply")
          .filter(visible: true)
          .click
        self
      end

      def click_replies_toggle(post)
        browser_root
          .locator("[data-post-number='#{post.post_number}'] .nested-post__expand-replies")
          .filter(visible: true)
          .click
        self
      end

      def click_load_more_children(post)
        browser_root
          .locator(
            wrapper_selector(
              post,
              "> .nested-post__main > .nested-post-children .nested-post-children__load-more",
            ),
          )
          .filter(visible: true)
          .click
        self
      end

      def trigger_replies_toggle(post)
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          (() => {
            const button = document.querySelector(
              "[data-post-number='#{post.post_number}'] .nested-post__expand-replies"
            );
            document
              .querySelectorAll(".nested-view__roots .nested-post [data-post-number]")
              .forEach((article) =>
                (article.closest(".nested-post") || article).getBoundingClientRect()
              );
            const scrollY = window.scrollY;
            button.click();
            return scrollY;
          })()
        JS
      end

      def scroll_post_near_top(post, offset: 80)
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
          const post = document.querySelector("[data-post-number='#{post.post_number}']");
          post.scrollIntoView();
          window.scrollBy(0, -#{offset});
        JS
        self
      end

      def scroll_past_topic_title
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
          window.scrollTo(0, document.body.scrollHeight);
        JS
        self
      end

      def click_reply_on_op
        browser_root
          .locator(".nested-view__op .post-action-menu__reply")
          .filter(visible: true)
          .click
        self
      end

      def click_continue_thread(post)
        within_browser(post_container(post)) do
          browser_root.locator(".nested-post__continue-link").filter(visible: true).click
        end
        self
      end

      def click_depth_line(post)
        browser_root.locator(depth_line_selector(post)).filter(visible: true).click
        self
      end

      def click_collapsed_bar(post)
        browser_root
          .locator(wrapper_selector(post, "> .nested-post__main > .nested-post__collapsed-bar"))
          .filter(visible: true)
          .click
        self
      end

      def click_mobile_ancestor(post)
        browser_root
          .locator("[data-test-nested-mobile-ancestor='#{post.post_number}']")
          .filter(visible: true)
          .click
        self
      end

      def click_mobile_ancestor_avatar(post)
        browser_root
          .locator(
            "[data-test-nested-mobile-ancestor='#{post.post_number}'] .nested-view__mobile-ancestor-avatar",
          )
          .filter(visible: true)
          .click
        self
      end

      def click_mobile_focus_back
        browser_root.locator(".nested-view__mobile-focus-back").filter(visible: true).click
        self
      end

      def click_floating_reply_button
        browser_root.locator(".nested-view__floating-reply").filter(visible: true).click
        self
      end

      def open_admin_menu
        browser_root
          .locator(".nested-view__floating-actions .toggle-admin-menu")
          .filter(visible: true)
          .click
        self
      end

      def click_admin_close_topic
        open_admin_menu
        browser_root.locator(".topic-admin-close .btn").filter(visible: true).click
        self
      end

      def click_admin_open_topic
        open_admin_menu
        browser_root.locator(".topic-admin-open .btn").filter(visible: true).click
        self
      end

      def change_notification_level(level)
        browser_root
          .locator(
            ".nested-view__floating-actions .topic-notifications-button .notifications-tracking-trigger-btn",
          )
          .filter(visible: true)
          .click
        browser_root
          .locator(".notifications-tracking-btn[data-level-id='#{level}']")
          .filter(visible: true)
          .click
        self
      end

      def click_copy_link_on_op
        within_browser(browser_root.locator(".nested-view__op").filter(visible: true)) do
          if browser_root.locator(".show-more-actions").filter(visible: true).count != 0
            browser_root.locator(".show-more-actions").filter(visible: true).click
          end
          browser_root.locator("button.post-action-menu__copy-link").filter(visible: true).click
        end
        self
      end

      def click_copy_link_on_post(post)
        within_browser(
          browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
        ) do
          if browser_root.locator(".show-more-actions").filter(visible: true).count != 0
            browser_root.locator(".show-more-actions").filter(visible: true).click
          end
          browser_root.locator("button.post-action-menu__copy-link").filter(visible: true).click
        end
        self
      end

      def click_sort(sort)
        browser_root.locator(".nested-sort-selector__trigger").filter(visible: true).click
        browser_root
          .locator(".dropdown-menu .btn")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.nested_replies.sort.#{sort}")))
          .click
        self
      end

      def scroll_to_position(scroll_y)
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            <<~JS
          const done = arguments[0];
          window.scrollTo(0, #{scroll_y});
          setTimeout(done, 50);
        JS
          } }).apply(this, args); }); }",
          arg: [],
        )
        self
      end

      def scroll_during_pending_restore(distance:)
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            <<~JS
          const done = arguments[0];
          const positions = { restored: window.scrollY };

          setTimeout(() => {
            window.scrollBy(0, #{distance});
            positions.afterUserScroll = window.scrollY;
          }, 20);

          setTimeout(() => {
            positions.afterRetries = window.scrollY;
            done(positions);
          }, 250);
        JS
          } }).apply(this, args); }); }",
          arg: [],
        )
      end

      def scroll_position_after_restore_window
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            <<~JS
          const done = arguments[0];
          const { SCROLL_RESTORE_WINDOW_MS } = require("discourse/components/nested");
          setTimeout(() => done(window.scrollY), SCROLL_RESTORE_WINDOW_MS + 50);
        JS
          } }).apply(this, args); }); }",
          arg: [],
        )
      end

      # ── Deletion/recovery assertions ─────────────────────────────

      def has_deleted_placeholder_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'].nested-post__placeholder--deleted",
          ).filter(visible: true),
        )
      end

      def has_no_deleted_placeholder_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'].nested-post__placeholder--deleted",
          ).filter(visible: true),
        )
      end

      def has_deleted_post_class_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-post--deleted [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_toggle_deleted_content_button_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] button.toggle-deleted-content",
          ).filter(visible: true),
        )
      end

      def has_no_toggle_deleted_content_button_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'] button.toggle-deleted-content",
          ).filter(visible: true),
        )
      end

      def click_toggle_deleted_content(post)
        browser_root
          .locator("[data-post-number='#{post.post_number}'] button.toggle-deleted-content")
          .filter(visible: true)
          .click
        self
      end

      def has_deleted_content_visible_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(wrapper_selector(post, ".nested-post__placeholder-reveal")).filter(
            visible: true,
          ),
        )
      end

      def has_no_deleted_content_visible_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(wrapper_selector(post, ".nested-post__placeholder-reveal")).filter(
            visible: true,
          ),
        )
      end

      # ── Ignored-user placeholder assertions ──────────────────────

      def has_ignored_placeholder_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'].nested-post__placeholder--ignored",
          ).filter(visible: true),
        )
      end

      def has_no_ignored_placeholder_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-post-number='#{post.post_number}'].nested-post__placeholder--ignored",
          ).filter(visible: true),
        )
      end

      def click_reveal_ignored(post)
        browser_root
          .locator(
            "button.nested-post__placeholder-avatar--reveal[data-post-number='#{post.post_number}']",
          )
          .filter(visible: true)
          .click
        self
      end

      # ── Post actions ────────────────────────────────────────────

      def click_post_delete_button(post)
        within_browser(
          browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
        ) do
          if PlaywrightMatchers.have_count(0, timeout: 2 * 1000).does_not_match?(
               browser_root.locator(".show-more-actions").filter(visible: true),
             )
            browser_root.locator(".show-more-actions").filter(visible: true).click
          end
          browser_root.locator("button.delete").filter(visible: true).click
        end
        self
      end

      def click_post_recover_button(post)
        selector = "[data-post-number='#{post.post_number}']"
        if PlaywrightMatchers.have_count(0, timeout: 5 * 1000).does_not_match?(
             browser_root.locator("#{selector} button.recover").filter(visible: true),
           )
          browser_root.locator("#{selector} button.recover").filter(visible: true).click
        else
          within_browser(selector) do
            browser_root.locator(".show-more-actions").filter(visible: true).click
            browser_root.locator("button.recover").filter(visible: true).click
          end
        end
        self
      end

      # ── Pinned post assertions ─────────────────────────────────

      def has_pinned_post?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-post--pinned [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_no_pinned_post?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".nested-post--pinned [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      # ── Load more ───────────────────────────────────────────────

      def has_load_more_roots_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__load-more").filter(visible: true),
        )
      end

      def click_load_more_roots
        browser_root.locator(".nested-view__load-more").filter(visible: true).click
        self
      end

      # ── Cloaking ─────────────────────────────────────────────────

      def has_cloaked_root?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".nested-view__roots > .nested-post--cloaked").filter(visible: true),
        )
      end

      def has_no_cloaked_root?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".nested-view__roots > .nested-post--cloaked").filter(visible: true),
        )
      end

      def has_cloaked_root_for?(post)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".nested-post--cloaked [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        )
      end

      def has_uncloaked_root_for?(post)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".nested-post--cloaked [data-post-number='#{post.post_number}']",
          ).filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true),
          )
      end

      # ── Suggested topics ──────────────────────────────────────────

      def has_suggested_topics?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#suggested-topics").filter(visible: true),
        )
      end

      def has_no_suggested_topics?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#suggested-topics").filter(visible: true),
        )
      end

      def has_suggested_topic?(topic)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#suggested-topics .topic-list-item[data-topic-id='#{topic.id}']",
          ).filter(visible: true),
        )
      end

      private

      def post_container(post)
        browser_root.locator("[data-post-number='#{post.post_number}']").filter(visible: true)
      end

      def wrapper_selector(post, child_selector = nil)
        # Builds a CSS selector that targets the DIRECT .nested-post wrapper for
        # the given post, without storing any find() results. Uses > combinators
        # to avoid matching ancestor .nested-post wrappers in the nested tree.
        base = ".nested-post:has(> .nested-post__main > [data-post-number='#{post.post_number}'])"
        child_selector ? "#{base} #{child_selector}" : base
      end

      def depth_line_selector(post)
        wrapper_selector(post, "> .nested-post__gutter .nested-post__depth-line")
      end

      def leaf_depth_line_selector(post)
        wrapper_selector(post, "> .nested-post__gutter .nested-post__depth-line--leaf")
      end
    end
  end
end
