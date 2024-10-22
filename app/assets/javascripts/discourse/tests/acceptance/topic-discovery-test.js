import { click, currentURL, settled, visit } from "@ember/test-helpers";
import { skip, test } from "qunit";
import { configureEyeline } from "discourse/lib/eyeline";
import { ScrollingDOMMethods } from "discourse/mixins/scrolling";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import topFixtures from "discourse/tests/fixtures/top-fixtures";
import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Topic Discovery", function (needs) {
  needs.settings({
    show_pinned_excerpt_desktop: true,
  });

  needs.pretender((server, helper) => {
    server.get("/hot.json", () => {
      return helper.response(cloneJSON(topFixtures["/top.json"]));
    });
  });

  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.ok(
      document.body.classList.contains("navigation-topics"),
      "has the default navigation"
    );
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    assert.strictEqual(
      query("a[data-user-card=eviltrout] img.avatar").getAttribute("title"),
      "eviltrout - Most Posts",
      "it shows user's full name in avatar title"
    );

    assert.strictEqual(
      query("a[data-user-card=eviltrout] img.avatar").getAttribute("loading"),
      "lazy",
      "it adds loading=`lazy` to topic list avatars"
    );

    await visit("/c/bug");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
    assert.ok(!exists(".category-list"), "doesn't render subcategories");
    assert.ok(
      document.body.classList.contains("category-bug"),
      "has a custom css class for the category id on the body"
    );

    await visit("/categories");
    assert.ok(
      document.body.classList.contains("navigation-categories"),
      "has the body class"
    );
    assert.ok(
      !document.body.classList.contains("category-bug"),
      "removes the custom category class"
    );
    assert.ok(exists(".category"), "has a list of categories");
    assert.ok(
      document.body.classList.contains("categories-list"),
      "has a custom class to indicate categories"
    );

    await visit("/top");
    assert.ok(
      !document.body.classList.contains("categories-list"),
      "removes the `categories-list` class"
    );
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    await visit("/c/feature");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".category-boxes"),
      "The list of subcategories were rendered with box style"
    );

    await visit("/c/dev");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".category-boxes-with-topics"),
      "The list of subcategories were rendered with box-with-featured-topics style"
    );
    assert.ok(
      exists(".category-boxes-with-topics .featured-topics"),
      "The featured topics are there too"
    );
  });

  test("Clearing state after leaving a category", async function (assert) {
    await visit("/c/dev");
    assert.ok(
      exists('.topic-list-item[data-topic-id="11994"] .topic-excerpt'),
      "it expands pinned topics in a subcategory"
    );
    await visit("/");
    assert.ok(
      !exists('.topic-list-item[data-topic-id="11557"] .topic-excerpt'),
      "it doesn't expand all pinned in the latest category"
    );
  });

  test("Live update unread state", async function (assert) {
    await visit("/");
    assert.ok(
      exists(".topic-list-item:not(.visited) a[data-topic-id='11995']"),
      "shows the topic unread"
    );

    await publishToMessageBus("/latest", {
      message_type: "read",
      topic_id: 11995,
      payload: {
        highest_post_number: 1,
        last_read_post_number: 2,
        notification_level: 1,
        topic_id: 11995,
      },
    });

    assert.ok(
      exists(".topic-list-item.visited a[data-topic-id='11995']"),
      "shows the topic read"
    );
  });

  test("Using period chooser when query params are present", async function (assert) {
    await visit("/top?status=closed");

    const periodChooser = selectKit(".period-chooser");
    await periodChooser.expand();
    await periodChooser.selectRowByValue("yearly");

    assert.strictEqual(currentURL(), "/top?period=yearly&status=closed");
  });

  test("switching between tabs", async function (assert) {
    await visit("/latest");
    assert.strictEqual(
      query(".topic-list-body .topic-list-item:first-of-type").dataset.topicId,
      "11557",
      "shows the correct latest topics"
    );

    await click(".navigation-container a[href='/hot']");
    assert.strictEqual(currentURL(), "/hot", "switches to hot");

    assert.deepEqual(
      query(".topic-list-body .topic-list-item:first-of-type").dataset.topicId,
      "13088",
      "shows the correct hot topics"
    );

    await click(".navigation-container a[href='/categories']");
    assert.strictEqual(currentURL(), "/categories", "switches to categories");
  });

  test("refreshing tabs", async function (assert) {
    const assertShowingLatest = (url) => {
      assert.strictEqual(currentURL(), url, "stays on latest");
      const el = query(".topic-list-body .topic-list-item:first-of-type");
      assert.strictEqual(el.closest(".hidden"), null, "topic list is visible");
      assert.strictEqual(
        el.dataset.topicId,
        "11557",
        "shows the correct topic"
      );
    };

    await visit("/latest");
    assertShowingLatest("/latest");

    await click(".navigation-container a[href='/latest']");
    assertShowingLatest("/latest");

    await click("#site-logo");
    assertShowingLatest("/");
  });
});

acceptance("Topic Discovery | Footer", function (needs) {
  needs.hooks.beforeEach(function () {
    ScrollingDOMMethods.bindOnScroll.restore();
    configureEyeline({
      skipUpdate: false,
      rootElement: "#ember-testing",
    });
  });

  needs.hooks.afterEach(function () {
    configureEyeline();
  });

  needs.pretender((server, helper) => {
    server.get("/c/dev/7/l/latest.json", (request) => {
      const json = cloneJSON(discoveryFixtures["/c/dev/7/l/latest.json"]);
      if (!request.queryParams.page) {
        json.topic_list.more_topics_url = "/c/dev/7/l/latest.json?page=2";
      }
      return helper.response(json);
    });
  });

  // TODO: Needs scroll support in tests
  skip("No footer, then shows footer when all loaded", async function (assert) {
    await visit("/c/dev");
    assert.dom(".custom-footer-content").doesNotExist();

    document.querySelector("#ember-testing-container").scrollTop = 100000; // scroll to bottom
    await settled();
    assert.dom(".custom-footer-content").exists();
  });
});
