import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import PostFlag from "discourse/lib/flag-targets/post-flag";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | flag-targets | post-flag", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    this.store = this.owner.lookup("service:store");
  });

  function buildFlagModal(post, selected) {
    return {
      args: { model: { flagModel: post } },
      selected,
    };
  }

  test("postActionFor resolves via actionByName by name_key", function (assert) {
    const post = this.store.createRecord("post", {
      id: 4001,
      post_number: 2,
      actions_summary: [
        { id: 8, can_act: true }, // spam
        { id: 6, can_act: true }, // notify_user
      ],
    });

    const postFlag = new PostFlag();
    const spamFlag = { id: 8, name_key: "spam" };
    const postAction = postFlag.postActionFor(buildFlagModal(post, spamFlag));

    assert.strictEqual(
      postAction,
      post.actionByName.spam,
      "returns the ActionSummary instance keyed by name_key"
    );
    assert.strictEqual(
      typeof postAction.act,
      "function",
      "the returned entry is a real ActionSummary with .act()"
    );
  });

  test("postActionFor still resolves when actions_summary has been trimmed", function (assert) {
    const post = this.store.createRecord("post", {
      id: 4002,
      post_number: 2,
      actions_summary: [
        { id: 8, can_act: true }, // spam
        { id: 7, can_act: true }, // notify_moderators
      ],
    });

    const staleActionByName = post.actionByName;
    post.actions_summary = [
      { id: 6, acted: true, count: 1, name_key: "notify_user" },
    ];

    const postFlag = new PostFlag();
    const notifyModeratorsFlag = { id: 7, name_key: "notify_moderators" };
    const postAction = postFlag.postActionFor(
      buildFlagModal(post, notifyModeratorsFlag)
    );

    assert.strictEqual(
      postAction,
      staleActionByName.notify_moderators,
      "falls back to the actionByName entry even after actions_summary drops it"
    );
  });
});
