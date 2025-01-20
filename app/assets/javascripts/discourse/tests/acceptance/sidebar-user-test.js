import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Sinon from "sinon";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Sidebar - Logged on user - Mobile view - Header dropdown navigation menu enabled",
  function (needs) {
    needs.user();
    needs.mobileView();

    needs.settings({
      navigation_menu: "header dropdown",
    });

    test("sections are collapsable", async function (assert) {
      await visit("/");
      await click("#toggle-hamburger-menu");

      assert
        .dom(".sidebar-section-header.sidebar-section-header-collapsable")
        .exists("sections are collapsable");
    });
  }
);

acceptance(
  "Sidebar - Logged on user - Desktop view - Header dropdown navigation menu enabled",
  function (needs) {
    needs.user();

    needs.settings({
      navigation_menu: "header dropdown",
    });

    test("showing and hiding sidebar", async function (assert) {
      await visit("/");
      await click("#toggle-hamburger-menu");

      assert
        .dom(".sidebar-hamburger-dropdown")
        .exists("displays the sidebar dropdown");

      await click("#toggle-hamburger-menu");

      assert
        .dom(".sidebar-hamburger-dropdown")
        .doesNotExist("hides the sidebar dropdown");
    });

    test("sections are not collapsable", async function (assert) {
      await visit("/");
      await click("#toggle-hamburger-menu");

      assert
        .dom(".sidebar-section-header.sidebar-section-header-collapsable")
        .doesNotExist("sections are not collapsable");
    });

    test("'more' dropdown should display as regular list items in header dropdown mode", async function (assert) {
      await visit("/");
      await click("#toggle-hamburger-menu");

      assert
        .dom("[data-link-name='admin']")
        .exists("the admin link is not within the 'more' dropdown");
      assert
        .dom(".sidebar-more-section-trigger")
        .doesNotExist(
          "the 'more' dropdown should not be present in header dropdown mode"
        );
    });
  }
);

acceptance(
  "Sidebar - Experimental sidebar and hamburger setting enabled - Sidebar enabled",
  function (needs) {
    needs.user({});

    needs.settings({
      navigation_menu: "sidebar",
    });

    test("viewing keyboard shortcuts using sidebar", async function (assert) {
      await visit("/");
      await click(
        `.sidebar-footer-actions-keyboard-shortcuts[title="${i18n(
          "keyboard_shortcuts_help.title"
        )}"]`
      );

      assert
        .dom("#keyboard-shortcuts-help")
        .exists("keyboard shortcuts help is displayed");
    });

    test("sidebar is disabled on wizard route", async function (assert) {
      await visit("/wizard");

      assert
        .dom(".sidebar-container")
        .doesNotExist("does not display the sidebar on wizard route");
    });

    test("showing and hiding sidebar", async function (assert) {
      await visit("/");

      assert
        .dom(document.body)
        .hasClass("has-sidebar-page", "adds sidebar utility class to body");

      assert
        .dom(".sidebar-container")
        .exists("displays the sidebar by default");

      await click(".btn-sidebar-toggle");

      assert
        .dom(document.body)
        .doesNotHaveClass(
          "has-sidebar-page",
          "removes sidebar utility class from body"
        );

      assert.dom(".sidebar-container").doesNotExist("hides the sidebar");

      await click(".btn-sidebar-toggle");

      assert.dom(".sidebar-container").exists("displays the sidebar");
    });

    test("button to toggle between mobile and desktop view on touch devices ", async function (assert) {
      const capabilities = this.container.lookup("service:capabilities");
      Sinon.stub(capabilities, "touch").value(true);

      await visit("/");

      assert
        .dom(
          `.sidebar-footer-actions-toggle-mobile-view[title="${i18n(
            "mobile_view"
          )}"]`
        )
        .exists("displays the right title for the button");

      assert
        .dom(
          ".sidebar-footer-actions-toggle-mobile-view .d-icon-mobile-screen-button"
        )
        .exists("displays the mobile icon for the button");
    });

    test("clean up topic tracking state state changed callbacks when sidebar is destroyed", async function (assert) {
      updateCurrentUser({ display_sidebar_tags: true });

      await visit("/");

      const topicTrackingState = this.container.lookup(
        "service:topic-tracking-state"
      );

      const initialCallbackCount = Object.keys(
        topicTrackingState.stateChangeCallbacks
      ).length;

      await click(".btn-sidebar-toggle");

      assert.strictEqual(
        Object.keys(topicTrackingState.stateChangeCallbacks).length,
        initialCallbackCount - 3,
        "the 3 topic tracking state change callbacks are removed"
      );
    });

    test("accessibility of sidebar section header", async function (assert) {
      await visit("/");

      assert
        .dom(
          ".sidebar-section[data-section-name='categories'] .sidebar-section-header[aria-expanded='true'][aria-controls='sidebar-section-content-categories']"
        )
        .exists(
          "accessibility attributes are set correctly on sidebar section header when section is expanded"
        );

      await click(".sidebar-section-header");

      assert
        .dom(
          ".sidebar-section[data-section-name='categories'] .sidebar-section-header[aria-expanded='false'][aria-controls='sidebar-section-content-categories']"
        )
        .exists(
          "accessibility attributes are set correctly on sidebar section header when section is collapsed"
        );
    });

    test("accessibility of sidebar toggle", async function (assert) {
      await visit("/");

      assert
        .dom(
          ".btn-sidebar-toggle[aria-expanded='true'][aria-controls='d-sidebar']"
        )
        .exists(
          "has the right accessibility attributes set when sidebar is expanded"
        );

      assert
        .dom(".btn-sidebar-toggle")
        .hasAttribute(
          "title",
          i18n("sidebar.title"),
          "has the right title attribute when sidebar is expanded"
        );

      await click(".btn-sidebar-toggle");

      assert
        .dom(
          ".btn-sidebar-toggle[aria-expanded='false'][aria-controls='d-sidebar']"
        )
        .exists(
          "has the right accessibility attributes set when sidebar is collapsed"
        );

      assert
        .dom(".btn-sidebar-toggle")
        .hasAttribute(
          "title",
          i18n("sidebar.title"),
          "has the right title attribute when sidebar is collapsed"
        );
    });
  }
);
