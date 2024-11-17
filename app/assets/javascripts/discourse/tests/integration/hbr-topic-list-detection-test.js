import { module, test } from "qunit";
import TopicList from "discourse/components/topic-list";
import TopicListItem from "discourse/components/topic-list-item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { rawConnectorsFor } from "discourse/lib/plugin-connectors";
import {
  addRawTemplate,
  needsHbrTopicList,
  removeRawTemplate,
} from "discourse-common/lib/raw-templates";

module("Integration | Lib | hbr topic list detection", function () {
  test("xyz template overrides", async function (assert) {
    try {
      addRawTemplate("flat-button", "non-topic list override");
      assert.false(needsHbrTopicList());

      addRawTemplate("list/topic-list-item", "topic list override");
      assert.true(needsHbrTopicList());
    } finally {
      removeRawTemplate("flat-button");
      removeRawTemplate("list/topic-list-item");
    }
  });

  test("xyz hbr connectors", async function (assert) {
    assert.false(needsHbrTopicList());

    // all raw connectors are topic list connectors
    addRawTemplate(
      "javascripts/raw-test/connectors/topic-list-after-title/foo",
      "topic list connector"
    );
    assert.strictEqual(rawConnectorsFor("topic-list-after-title").length, 1);
    assert.true(needsHbrTopicList());
  });

  test("xyz reopen", async function (assert) {
    // updated calls are allowed
    TopicList.deprecatedReopen({});
    assert.false(needsHbrTopicList());

    // old calls are detected
    TopicList.reopen({});
    assert.true(needsHbrTopicList());
  });

  test("xyz reopenClass", async function (assert) {
    // updated calls are allowed
    TopicListItem.deprecatedReopenClass({});
    assert.false(needsHbrTopicList());

    // old calls are detected
    TopicListItem.reopenClass({});
    assert.true(needsHbrTopicList());
  });

  test("xyz modifyClass", async function (assert) {
    withPluginApi("1.0.0", (api) => {
      api.modifyClass(
        "component:mobile-nav",
        (Superclass) => class extends Superclass {}
      );
      assert.false(needsHbrTopicList());

      api.modifyClass(
        "component:topic-list-item",
        (Superclass) => class extends Superclass {},
        { hasModernReplacement: true }
      );
      assert.false(needsHbrTopicList());

      api.modifyClass(
        "component:topic-list-item",
        (Superclass) => class extends Superclass {}
      );
      assert.true(needsHbrTopicList());
    });
  });

  test("xyz modifyClassStatic", async function (assert) {
    withPluginApi("1.0.0", (api) => {
      api.modifyClassStatic("component:mobile-nav", { pluginId: "test" });
      assert.false(needsHbrTopicList());

      api.modifyClassStatic(
        "component:topic-list",
        { pluginId: "test" },
        { hasModernReplacement: true }
      );
      assert.false(needsHbrTopicList());

      api.modifyClassStatic("component:topic-list", { pluginId: "test" });
      assert.true(needsHbrTopicList());
    });
  });
});
