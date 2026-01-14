import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DiscoveryTopics from "discourse/components/discovery/topics";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function createModel(attrs = {}) {
  return EmberObject.create({
    filter: attrs.filter ?? "latest",
    topics: attrs.topics ?? [],
    more_topics_url: attrs.more_topics_url ?? null,
    params: attrs.params ?? {},
    canLoadMore: attrs.canLoadMore ?? false,
    loadingMore: attrs.loadingMore ?? false,
    sharedDrafts: attrs.sharedDrafts ?? null,
    hideCategory: attrs.hideCategory ?? false,
    loadingBefore: attrs.loadingBefore ?? false,
  });
}

module("Integration | Component | DiscoveryTopics", function (hooks) {
  setupRenderingTest(hooks);

  module("showEmptyFilterEducationInFooter", function () {
    test("shows EmptyTopicFilter when all topics loaded and list is empty", async function (assert) {
      const model = createModel({
        topics: [],
        more_topics_url: null,
      });

      await render(<template><DiscoveryTopics @model={{model}} /></template>);

      assert.dom(".empty-state__container.--empty-topic-filter").exists();
    });

    test("does not show EmptyTopicFilter when there are more topics to load", async function (assert) {
      const model = createModel({
        topics: [],
        more_topics_url: "/latest?page=2",
      });

      await render(<template><DiscoveryTopics @model={{model}} /></template>);

      assert.dom(".empty-state--empty-topic-filter").doesNotExist();
    });

    test("does not show EmptyTopicFilter when topics exist", async function (assert) {
      const model = createModel({
        topics: [EmberObject.create({ id: 1, title: "Test topic" })],
        more_topics_url: null,
      });

      await render(<template><DiscoveryTopics @model={{model}} /></template>);

      assert.dom(".empty-state--empty-topic-filter").doesNotExist();
    });

    test("does not show EmptyTopicFilter for anonymous users", async function (assert) {
      this.owner.unregister("service:current-user");
      this.owner.register("service:current-user", null, { instantiate: false });

      const model = createModel({
        topics: [],
        more_topics_url: null,
      });

      await render(<template><DiscoveryTopics @model={{model}} /></template>);

      assert.dom(".empty-state--empty-topic-filter").doesNotExist();
    });
  });
});
