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

  test("falls back to plain text when rich HTML converts to empty markdown", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain", "text/html"],
        getData(type) {
          if (type === "text/plain") {
            return "plain fallback";
          }
          if (type === "text/html") {
            return "<span></span>";
          }
        },
      },
    });

    assert.true(prevented, "native paste is prevented for handled rich paste");
    assert.strictEqual(textarea.value, "plain fallback");
  });
});
