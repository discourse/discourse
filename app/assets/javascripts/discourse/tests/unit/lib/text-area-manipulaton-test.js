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
});
