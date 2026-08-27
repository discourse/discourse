import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import PreloadStore from "discourse/lib/preload-store";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function preloadTopicList(filter) {
  const list = cloneJSON(discoveryFixtures["/c/bug/1/l/latest.json"]);
  list.topic_list.filter = filter;
  PreloadStore.store("topic_list", list);
}

function topicListRequests() {
  return pretender.handledRequests
    .filter((request) => request.url.includes("/l/"))
    .map((request) => request.url.split("?")[0]);
}

acceptance("Topic list preload", function () {
  test("uses a preloaded list built for the requested filter", async function (assert) {
    preloadTopicList("latest");

    await visit("/c/bug/1/l/latest");

    assert.dom(".topic-list-item").exists();
    assert.deepEqual(
      topicListRequests(),
      [],
      "does not request a list it already has"
    );
  });

  test("discards a preloaded list built for a different filter", async function (assert) {
    preloadTopicList("top");

    await visit("/c/bug/1/l/latest");

    assert.dom(".topic-list-item").exists();
    assert.deepEqual(
      topicListRequests(),
      ["/c/bug/1/l/latest.json"],
      "requests the list it actually asked for"
    );
  });

  test("uses a preloaded list that does not report a filter", async function (assert) {
    preloadTopicList(undefined);

    await visit("/c/bug/1/l/latest");

    assert.dom(".topic-list-item").exists();
    assert.deepEqual(
      topicListRequests(),
      [],
      "an older server payload is still usable"
    );
  });
});
