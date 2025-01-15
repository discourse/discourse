import { module, test } from "qunit";
import TopicList from "discourse/components/topic-list";
import TopicListItem from "discourse/components/topic-list-item";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { rawConnectorsFor } from "discourse/lib/plugin-connectors";
import {
  addRawTemplate,
  needsHbrTopicList,
  removeRawTemplate,
} from "discourse/lib/raw-templates";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Integration | Lib | hbr topic list detection", function (hooks) {
  hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
  });

  hooks.afterEach(function () {
    enableRaiseOnDeprecation();
  });

  test("template overrides", async function (assert) {
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

  test("hbr connectors", async function (assert) {
    assert.false(needsHbrTopicList());

    // all raw connectors are topic list connectors
    addRawTemplate(
      "javascripts/raw-test/connectors/topic-list-after-title/foo",
      "topic list connector"
    );
    assert.strictEqual(rawConnectorsFor("topic-list-after-title").length, 1);
    assert.true(needsHbrTopicList());
  });

  test("reopen", async function (assert) {
    withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
      TopicList.reopen({});
    });
    assert.false(needsHbrTopicList());

    TopicList.reopen({});
    assert.true(needsHbrTopicList());
  });

  test("reopenClass", async function (assert) {
    withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
      TopicListItem.reopenClass({});
    });
    assert.false(needsHbrTopicList());

    TopicListItem.reopenClass({});
    assert.true(needsHbrTopicList());
  });

  test("modifyClass", async function (assert) {
    withPluginApi("1.0.0", (api) => {
      api.modifyClass(
        "component:mobile-nav",
        (Superclass) => class extends Superclass {}
      );
      assert.false(needsHbrTopicList());

      withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
        api.modifyClass(
          "component:topic-list-item",
          (Superclass) => class extends Superclass {}
        );
      });
      assert.false(needsHbrTopicList());

      api.modifyClass(
        "component:topic-list-item",
        (Superclass) => class extends Superclass {}
      );
      assert.true(needsHbrTopicList());
    });
  });

  test("modifyClassStatic", async function (assert) {
    withPluginApi("1.0.0", (api) => {
      api.modifyClassStatic("component:mobile-nav", { pluginId: "test" });
      assert.false(needsHbrTopicList());

      withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
        api.modifyClassStatic("component:topic-list", { pluginId: "test" });
      });
      assert.false(needsHbrTopicList());

      api.modifyClassStatic("component:topic-list", { pluginId: "test" });
      assert.true(needsHbrTopicList());
    });
  });
});
