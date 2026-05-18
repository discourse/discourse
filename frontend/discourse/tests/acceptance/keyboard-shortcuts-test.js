import {
  click,
  currentURL,
  fillIn,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance, chromeTest } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Keyboard Shortcuts - Anonymous Users", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/27331/4.json", () => helper.response({}));
    server.get("/t/27331.json", () => helper.response({}));
    server.get("/t/27331/last.json", () => helper.response({}));

    // No suggested topics exist.
    server.get("/t/9/last.json", () => helper.response({}));

    // Suggested topic is returned by server.
    server.get("/t/28830/last.json", () => {
      return helper.response({
        suggested_topics: [
          {
            id: 27331,
            slug: "keyboard-shortcuts-are-awesome",
          },
        ],
      });
    });
  });

  test("go to first suggested topic", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await triggerKeyEvent(document, "keypress", "G");
    await triggerKeyEvent(document, "keypress", "S");
    assert.true(currentURL().startsWith("/t/this-is-a-test-topic/9"));

    // Suggested topics elements exist.
    await visit("/t/internationalization-localization/280");
    await triggerKeyEvent(document, "keypress", "G");
    await triggerKeyEvent(document, "keypress", "S");
    assert.strictEqual(currentURL(), "/t/polls-are-still-very-buggy/27331/4");

    await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
    await triggerKeyEvent(document, "keypress", "G");
    await triggerKeyEvent(document, "keypress", "S");
    assert.strictEqual(currentURL(), "/t/keyboard-shortcuts-are-awesome/27331");
  });

  test("j/k navigation moves selection up/down", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await triggerKeyEvent(document, "keypress", "J");
    assert
      .dom(".post-stream .topic-post.selected #post_1")
      .exists("first post is selected");

    await triggerKeyEvent(document, "keypress", "J");
    assert
      .dom(".post-stream .topic-post.selected #post_2")
      .exists("pressing j moves selection to next post");

    await triggerKeyEvent(document, "keypress", "K");
    assert
      .dom(".post-stream .topic-post.selected #post_1")
      .exists("pressing k moves selection to previous post");
  });

  // FIXME: For reasons unknown this test is flaky on firefox
  chromeTest("j/k navigation skips hidden elements", async function (assert) {
    await visit("/t/internationalization-localization/280");

    document.querySelector("#qunit-fixture").innerHTML = `
      <style>
        #post_2, #post_3 { display: none; }
      </style>
    `;

    await triggerKeyEvent(document, "keypress", "J");

    assert
      .dom(".post-stream .topic-post.selected article")
      .hasAttribute("id", "post_1", "first post is selected");

    await triggerKeyEvent(document, "keypress", "J");

    assert
      .dom(".post-stream .topic-post.selected article")
      .hasAttribute(
        "id",
        "post_4",
        "pressing j moves selection to next visible post"
      );

    await triggerKeyEvent(document, "keypress", "K");

    assert
      .dom(".post-stream .topic-post.selected article")
      .hasAttribute(
        "id",
        "post_1",
        "pressing k moves selection to previous visible post"
      );
  });
});

acceptance("Keyboard Shortcuts - Authenticated Users", function (needs) {
  let resetNewCalled;
  let markReadCalled;
  let topicList;

  needs.user();
  needs.hooks.beforeEach(() => {
    resetNewCalled = 0;
    markReadCalled = 0;
    topicList = cloneJSON(DiscoveryFixtures["/latest.json"]);

    // get rid of some of the topics and the more_topics_url
    // so we consider them allLoaded and show the footer with
    // the bottom dismiss button
    topicList.topic_list.topics.splice(20, 30);
    topicList.topic_list.more_topics_url = null;
  });
  needs.pretender((server, helper) => {
    server.get("/unread.json", () => {
      return helper.response(topicList);
    });
    server.get("/new.json", () => {
      return helper.response(topicList);
    });
    server.get("/unseen.json", () => {
      return helper.response(topicList);
    });
    server.put("/topics/reset-new", () => {
      resetNewCalled += 1;
      return helper.response({});
    });
    server.put("/topics/bulk", () => {
      markReadCalled += 1;
      return helper.response({});
    });
  });

  test("dismiss unread from top and bottom button", async function (assert) {
    // need to scroll to top so the viewport shows the top of the page
    // and top dismiss button
    await visit("/");
    document.getElementById("ember-testing-container").scrollTop = 0;
    await visit("/unread");
    assert
      .dom("#dismiss-topics-top")
      .exists("dismiss unread top button is present");
    await triggerKeyEvent(document, "keydown", "D", { shiftKey: true });
    assert
      .dom("#dismiss-read-confirm")
      .exists("confirmation modal to dismiss unread is present");
    assert
      .dom(".d-modal__body")
      .hasText(i18n("topics.bulk.also_dismiss_topics"));
    await click("#dismiss-read-confirm");
    assert.strictEqual(
      markReadCalled,
      1,
      "mark read has been called on the backend once"
    );

    // we get rid of all but one topic so the bottom dismiss button doesn't
    // show up, as it only appears if there are too many topics pushing
    // the bottom button out of the viewport
    let originalTopics = [...topicList.topic_list.topics];
    topicList.topic_list.topics = [topicList.topic_list.topics[0]];

    // visit root first so topic list starts fresh
    await visit("/");
    await visit("/unread");
    assert
      .dom("#dismiss-topics-bottom")
      .doesNotExist("dismiss unread bottom button is hidden");

    await triggerKeyEvent(document, "keydown", "D", { shiftKey: true });
    assert
      .dom("#dismiss-read-confirm")
      .exists("confirmation modal to dismiss unread is present");
    assert
      .dom(".d-modal__body")
      .hasText(
        "Stop tracking these topics so they never show up as unread for me again"
      );

    await click("#dismiss-read-confirm");
    assert.strictEqual(
      markReadCalled,
      2,
      "mark read has been called on the backend twice"
    );

    // restore the original topic list
    topicList.topic_list.topics = originalTopics;
  });

  test("dismiss new from top and bottom button", async function (assert) {
    // need to scroll to top so the viewport shows the top of the page
    // and top dismiss button
    await visit("/");
    document.getElementById("ember-testing-container").scrollTop = 0;
    await visit("/new");
    assert.dom("#dismiss-new-top").exists("dismiss new top button is present");

    await triggerKeyEvent(document, "keydown", "D", { shiftKey: true });
    assert.strictEqual(resetNewCalled, 1);

    // we get rid of all but one topic so the bottom dismiss button doesn't
    // show up, as it only appears if there are too many topics pushing
    // the bottom button out of the viewport
    let originalTopics = [...topicList.topic_list.topics];
    topicList.topic_list.topics = [topicList.topic_list.topics[0]];

    // visit root first so topic list starts fresh
    await visit("/");
    await visit("/new");
    assert
      .dom("#dismiss-new-bottom")
      .doesNotExist("dismiss new bottom button has been hidden");

    await triggerKeyEvent(document, "keydown", "D", { shiftKey: true });
    assert.strictEqual(resetNewCalled, 2);

    // restore the original topic list
    topicList.topic_list.topics = originalTopics;
  });

  test("click event not fired twice when both dismiss buttons are present", async function (assert) {
    // need to scroll to top so the viewport shows the top of the page
    // and top dismiss button
    await visit("/");
    document.getElementById("ember-testing-container").scrollTop = 0;
    await visit("/new");
    assert
      .dom("#dismiss-new-top")
      .exists("dismiss new top button is present before double click test");
    assert
      .dom("#dismiss-new-bottom")
      .exists("dismiss new bottom button is present");

    await triggerKeyEvent(document, "keydown", "D", { shiftKey: true });

    assert.strictEqual(resetNewCalled, 1);
  });

  test("share shortcuts", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await triggerKeyEvent(document, "keypress", "J");
    assert
      .dom(".post-stream .topic-post.selected #post_1")
      .exists("first post is selected");

    await triggerKeyEvent(document, "keypress", "J");
    assert
      .dom(".post-stream .topic-post.selected #post_2")
      .exists("pressing j moves selection to next post");

    await triggerKeyEvent(document, "keypress", "S");
    assert
      .dom(".d-modal.share-topic-modal")
      .exists("post-specific share modal is open");
    assert
      .dom("#discourse-modal-title")
      .hasText(i18n("post.share.title", { post_number: 2 }));
    await click(".modal-close");

    await triggerKeyEvent(document, "keydown", "S", { shiftKey: true });
    assert
      .dom(".d-modal.share-topic-modal")
      .exists("topic level share modal is open");
    assert.dom("#discourse-modal-title").hasText(i18n("topic.share.title"));

    await click(".modal-close");
  });

  test("g y navigates to /unseen", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "G");
    await triggerKeyEvent(document, "keypress", "Y");
    assert.strictEqual(currentURL(), "/unseen");
  });

  module("context aware create new shortcuts", function () {
    test("C key opens composer in new topic mode from topics list", async function (assert) {
      await visit("/");
      await triggerKeyEvent(document, "keypress", "C");

      assert
        .dom(".composer-action-create-topic .composer-action-title")
        .includesText(
          i18n("composer.composer_actions.create_topic.desc"),
          "composer shows create topic title"
        );
    });

    test("C key opens composer in new PM mode from messages list", async function (assert) {
      await visit("/my/messages");
      await triggerKeyEvent(document, "keypress", "C");

      assert
        .dom(".composer-action-private-message .composer-action-title")
        .includesText(
          i18n("topic.private_message"),
          "composer shows create message title"
        );
    });

    test("C key opens composer in new PM mode from PM topic", async function (assert) {
      await visit("/t/pm-for-testing/12");
      await triggerKeyEvent(document, "keypress", "C");

      assert
        .dom(".composer-action-private-message .composer-action-title")
        .includesText(
          i18n("topic.private_message"),
          "composer shows create message title"
        );
    });
  });
});

acceptance("Keyboard Shortcuts Help Modal - Search", function () {
  async function openHelpModal() {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));
  }

  function description(key) {
    return i18n(`keyboard_shortcuts_help.${key}`, { shortcut: "" }).trim();
  }

  test("matches sequential keys without whitespace (gh → G H)", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "gh");

    assert
      .dom(".shortcut-category-jump_to tbody")
      .includesText(description("jump_to.home"));
    assert
      .dom(".shortcut-category-jump_to tbody")
      .doesNotIncludeText(description("jump_to.latest"));
  });

  test("requires every search token to match (command /)", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "command /");

    assert
      .dom(".shortcut-category-application tbody")
      .includesText(description("application.filter_sidebar"));
    assert
      .dom(".shortcut-category-application tbody")
      .doesNotIncludeText(description("application.help"));
  });

  test("modifier aliases match regardless of glyph (ctrl)", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "ctrl");

    assert
      .dom(".shortcut-category-application tbody")
      .includesText(description("application.search"));
  });

  test("multi-word description match", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "open keyboard help");

    assert
      .dom(".shortcut-category-application tbody")
      .includesText(description("application.help"));
    assert
      .dom(".shortcut-category-jump_to")
      .doesNotExist("unrelated categories are filtered out");
  });

  test("alternative key groups don't merge for compact match", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "kj");

    // navigation.up_down is K or J, not K then J. "kj" must not
    // match it just because both letters appear across the alternative groups.
    assert
      .dom(".shortcut-category-navigation")
      .doesNotExist(
        "alternative key groups don't false-match the merged compact form"
      );
  });

  test("alternative key groups don't satisfy tokens across alternatives", async function (assert) {
    await openHelpModal();
    await fillIn(".filter-input", "ctrl /");

    // application.search has alternatives "/" or Ctrl+Alt+F. "ctrl /" must not
    // match because "ctrl" lives in one alternative and "/" in the other.
    assert
      .dom(".shortcut-category-application tbody")
      .doesNotIncludeText(description("application.search"));
  });

  test("plugin-registered shortcut with raw 'esc' key matches escape alias", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("shift+esc", () => {}, {
        help: {
          category: "esc_test",
          name: "esc_test.bail",
          definition: { keys1: ["shift", "esc"] },
        },
      });
    });

    await openHelpModal();
    await fillIn(".filter-input", "escape");

    assert.dom(".shortcut-category-esc_test tbody tr").exists({ count: 1 });
  });
});
