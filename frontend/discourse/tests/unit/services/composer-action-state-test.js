import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

function topic(id = 1) {
  return { id, title: `Topic ${id}` };
}

function post(id = 10) {
  return { id, username: `user${id}` };
}

module("Unit | Service | composer-action-state", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.composerActionState = getOwner(this).lookup(
      "service:composer-action-state"
    );
  });

  test("remember stores topic/post when provided", function (assert) {
    const rememberedTopic = topic();
    const rememberedPost = post();

    this.composerActionState.remember({
      topic: rememberedTopic,
      post: rememberedPost,
    });

    assert.deepEqual(this.composerActionState.snapshot, {
      topic: rememberedTopic,
      post: rememberedPost,
    });
  });

  test("null topic does not erase existing snapshot during intentional mode switches", function (assert) {
    const rememberedTopic = topic();
    const rememberedPost = post();

    this.composerActionState.remember({
      topic: rememberedTopic,
      post: rememberedPost,
    });
    this.composerActionState.remember({ topic: null, post: null });

    assert.deepEqual(this.composerActionState.snapshot, {
      topic: rememberedTopic,
      post: rememberedPost,
    });
  });

  test("clear removes stale context", function (assert) {
    this.composerActionState.remember({ topic: topic(), post: post() });
    this.composerActionState.clear();

    assert.deepEqual(this.composerActionState.snapshot, {
      topic: null,
      post: null,
    });
  });

  test("selectAction returns false for plugin/custom actions", async function (assert) {
    assert.false(
      await this.composerActionState.selectAction("plugin_action", {
        options: {},
        composerModel: {},
        topic: null,
        post: null,
      })
    );
  });
});
