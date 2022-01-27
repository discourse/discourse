import { click, currentURL, triggerKeyEvent, visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "I18n";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { test } from "qunit";

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
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.strictEqual(currentURL(), "/t/this-is-a-test-topic/9");

    // Suggested topics elements exist.
    await visit("/t/internationalization-localization/280");
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.strictEqual(currentURL(), "/t/polls-are-still-very-buggy/27331/4");

    await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.strictEqual(currentURL(), "/t/keyboard-shortcuts-are-awesome/27331");
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
    assert.ok(
      exists("#dismiss-topics-top"),
      "dismiss unread top button is present"
    );
    await triggerKeyEvent(document, "keypress", "x".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "t".charCodeAt(0));
    assert.ok(
      exists("#dismiss-read-confirm"),
      "confirmation modal to dismiss unread is present"
    );
    assert.strictEqual(
      query(".modal-body").innerText,
      I18n.t("topics.bulk.also_dismiss_topics")
    );
    await click("#dismiss-read-confirm");
    assert.strictEqual(
      markReadCalled,
      1,
      "mark read has been called on the backend once"
    );

    // we get rid of all but one topic so the top dismiss button doesn't
    // show up, as it only appears if there are too many topics pushing
    // the bottom button out of the viewport
    let originalTopics = [...topicList.topic_list.topics];
    topicList.topic_list.topics = [topicList.topic_list.topics[0]];

    // visit root first so topic list starts fresh
    await visit("/");
    await visit("/unread");
    assert.notOk(
      exists("#dismiss-topics-top"),
      "dismiss unread top button is hidden"
    );
    await triggerKeyEvent(document, "keypress", "x".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "t".charCodeAt(0));
    assert.ok(
      exists("#dismiss-read-confirm"),
      "confirmation modal to dismiss unread is present"
    );
    assert.strictEqual(
      query(".modal-body").innerText,
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
    assert.ok(exists("#dismiss-new-top"), "dismiss new top button is present");
    await triggerKeyEvent(document, "keypress", "x".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "r".charCodeAt(0));
    assert.strictEqual(resetNewCalled, 1);

    // we get rid of all but one topic so the top dismiss button doesn't
    // show up, as it only appears if there are too many topics pushing
    // the bottom button out of the viewport
    let originalTopics = [...topicList.topic_list.topics];
    topicList.topic_list.topics = [topicList.topic_list.topics[0]];

    // visit root first so topic list starts fresh
    await visit("/");
    await visit("/new");
    assert.notOk(
      exists("#dismiss-new-top"),
      "dismiss new top button has been hidden"
    );
    await triggerKeyEvent(document, "keypress", "x".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "r".charCodeAt(0));
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
    assert.ok(
      exists("#dismiss-new-top"),
      "dismiss new top button is present before double click test"
    );
    assert.ok(
      exists("#dismiss-new-bottom"),
      "dismiss new bottom button is present"
    );

    await triggerKeyEvent(document, "keypress", "x".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "r".charCodeAt(0));

    assert.strictEqual(resetNewCalled, 1);
  });
});
