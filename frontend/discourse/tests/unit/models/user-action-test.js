import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UserAction from "discourse/models/user-action";

module("Unit | Model | user-action", function (hooks) {
  setupTest(hooks);

  test("collapsing likes", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const actions = UserAction.collapseStream([
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 1,
        post_number: 1,
      }),
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.edits,
        topic_id: 2,
        user_id: 1,
        post_number: 1,
      }),
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 2,
        post_number: 1,
      }),
    ]);

    assert.strictEqual(actions.length, 2);
    assert.strictEqual(actions[0].children.length, 1);
    assert.strictEqual(actions[0].children[0].items.length, 2);
  });

  test("titleHtml escapes HTML and unescapes emojis", function (assert) {
    const store = getOwner(this).lookup("service:store");

    // Test with plain text
    const plainAction = store.createRecord("user-action", {
      title: "Hello World",
    });
    assert.strictEqual(
      plainAction.titleHtml,
      "Hello World",
      "returns plain text unchanged"
    );

    // Test with HTML that needs escaping
    const htmlAction = store.createRecord("user-action", {
      title: "<script>alert('xss')</script>",
    });
    assert.strictEqual(
      htmlAction.titleHtml,
      "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;",
      "escapes dangerous HTML"
    );

    // Test with emoji
    const emojiAction = store.createRecord("user-action", {
      title: "Great post :smile:",
    });
    assert.true(
      emojiAction.titleHtml.includes("<img"),
      "converts emoji to image tag"
    );
    assert.true(
      emojiAction.titleHtml.includes("smile"),
      "includes emoji name in output"
    );

    // Test with both HTML and emoji
    const mixedAction = store.createRecord("user-action", {
      title: "Cool <b>post</b> :heart:",
    });
    assert.true(
      mixedAction.titleHtml.includes("&lt;b&gt;"),
      "escapes HTML tags"
    );
    assert.true(
      mixedAction.titleHtml.includes("<img"),
      "still converts emojis"
    );

    // Test with null/undefined
    const nullAction = store.createRecord("user-action", {
      title: null,
    });
    assert.strictEqual(
      nullAction.titleHtml,
      null,
      "returns null when title is null"
    );

    const undefinedAction = store.createRecord("user-action", {});
    assert.strictEqual(
      undefinedAction.titleHtml,
      undefined,
      "returns undefined when title is undefined"
    );

    // Test with empty string
    const emptyAction = store.createRecord("user-action", {
      title: "",
    });
    assert.strictEqual(
      emptyAction.titleHtml,
      "",
      "returns empty string when title is empty"
    );
  });
});
