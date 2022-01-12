import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import { test } from "qunit";
import { click, currentURL, visit } from "@ember/test-helpers";

acceptance("Topic Discovery", function (needs) {
  needs.settings({
    show_pinned_excerpt_desktop: true,
  });

  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.ok($("body.navigation-topics").length, "has the default navigation");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    assert.strictEqual(
      queryAll("a[data-user-card=eviltrout] img.avatar").attr("title"),
      "Evil Trout - Most Posts",
      "it shows user's full name in avatar title"
    );

    assert.strictEqual(
      queryAll("a[data-user-card=eviltrout] img.avatar").attr("loading"),
      "lazy",
      "it adds loading=`lazy` to topic list avatars"
    );

    await visit("/c/bug");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
    assert.ok(!exists(".category-list"), "doesn't render subcategories");
    assert.ok(
      $("body.category-bug").length,
      "has a custom css class for the category id on the body"
    );

    await visit("/categories");
    assert.ok($("body.navigation-categories").length, "has the body class");
    assert.ok(
      $("body.category-bug").length === 0,
      "removes the custom category class"
    );
    assert.ok(exists(".category"), "has a list of categories");
    assert.ok(
      $("body.categories-list").length,
      "has a custom class to indicate categories"
    );

    await visit("/top");
    assert.ok(
      $("body.categories-list").length === 0,
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

    publishToMessageBus("/latest", {
      message_type: "read",
      topic_id: 11995,
      payload: {
        highest_post_number: 1,
        last_read_post_number: 2,
        notification_level: 1,
        topic_id: 11995,
      },
    });

    await visit("/"); // We're already there, but use this to wait for re-render

    assert.ok(
      exists(".topic-list-item.visited a[data-topic-id='11995']"),
      "shows the topic read"
    );
  });

  test("Using period chooser when query params are present", async function (assert) {
    await visit("/top?f=foo&d=bar");

    sinon.stub(DiscourseURL, "routeTo");

    const periodChooser = selectKit(".period-chooser");

    await periodChooser.expand();
    await periodChooser.selectRowByValue("yearly");

    assert.ok(
      DiscourseURL.routeTo.calledWith("/top?f=foo&d=bar&period=yearly"),
      "it keeps the query params"
    );
  });

  test("switching between tabs", async function (assert) {
    await visit("/latest");
    assert.strictEqual(
      query(".topic-list-body .topic-list-item:first-of-type").dataset.topicId,
      "11557",
      "shows the correct latest topics"
    );

    await click(".navigation-container a[href='/top']");
    assert.strictEqual(currentURL(), "/top", "switches to top");

    assert.deepEqual(
      query(".topic-list-body .topic-list-item:first-of-type").dataset.topicId,
      "13088",
      "shows the correct top topics"
    );

    await click(".navigation-container a[href='/categories']");
    assert.strictEqual(currentURL(), "/categories", "switches to categories");
  });

  test("refreshing tabs", async function (assert) {
    const assertShowingLatest = () => {
      assert.strictEqual(currentURL(), "/latest", "stays on latest");
      const el = query(".topic-list-body .topic-list-item:first-of-type");
      assert.strictEqual(el.closest(".hidden"), null, "topic list is visible");
      assert.strictEqual(
        el.dataset.topicId,
        "11557",
        "shows the correct topic"
      );
    };

    await visit("/latest");
    assertShowingLatest();

    await click(".navigation-container a[href='/latest']");
    assertShowingLatest();

    await click("#site-logo");
    assertShowingLatest();
  });
});
