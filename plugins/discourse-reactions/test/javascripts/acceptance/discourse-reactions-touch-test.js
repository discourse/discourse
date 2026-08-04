import { find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

function dispatchTouch(element, type) {
  element.dispatchEvent(new TouchEvent(type, { bubbles: true }));
}

acceptance("Reactions touch gestures", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
  });

  needs.pretender((server, helper) => {
    const topicPath = "/t/374.json";
    server.get(topicPath, () => helper.response(ReactionsTopics[topicPath]));
  });

  needs.hooks.beforeEach(function () {
    sinon
      .stub(this.owner.lookup("service:capabilities"), "touch")
      .get(() => true);
  });

  test("post text stays selectable after scrolling off a reaction button", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    const button = find("#post_2 .discourse-reactions-reaction-button");
    dispatchTouch(button, "touchstart");
    dispatchTouch(button, "touchmove");
    await settled();

    assert.notStrictEqual(
      getComputedStyle(find("#post_2 .cooked")).userSelect,
      "none",
      "leaves post text selectable, so quoting still works"
    );
  });

  test("the reaction button itself is never selectable", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert.strictEqual(
      getComputedStyle(find("#post_2 .discourse-reactions-reaction-button"))
        .userSelect,
      "none",
      "a long-press on the button cannot start a selection"
    );
  });

  test("a touch cancelled by the browser does not expand the picker", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    const button = find("#post_2 .discourse-reactions-reaction-button");
    dispatchTouch(button, "touchstart");
    dispatchTouch(button, "touchcancel");
    await settled();

    assert
      .dom("#post_2 .discourse-reactions-picker.is-expanded")
      .doesNotExist("the pending long-press is abandoned");
  });
});
