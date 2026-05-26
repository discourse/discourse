import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

module("Unit | Utility | text-area-manipulation", function (hooks) {
  setupTest(hooks);

  test("applySurround - add", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "Hello World";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");

    assert.strictEqual(textarea.value, "**Hello World**");
  });

  test("applySurround - remove", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "**Hello World**";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");

    assert.strictEqual(textarea.value, "Hello World");
  });

  test("applySurround - one side", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "Hello World**";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");
    assert.strictEqual(textarea.value, "**Hello World****");

    textarea.value = "**Hello World";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");
    assert.strictEqual(textarea.value, "****Hello World**");
  });

  test("emojiSelected - replaces ASCII partial term", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = ":trau";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("disappointed");

    assert.strictEqual(textarea.value, ":disappointed:");
  });

  test("emojiSelected - replaces partial term containing Unicode letters", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = ":glücklich";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("smile");

    assert.strictEqual(textarea.value, ":smile:");
  });

  test("emojiSelected - appends emoji when no partial term is present", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "hello";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("smile");

    assert.strictEqual(textarea.value, "hello :smile:");
  });
});
