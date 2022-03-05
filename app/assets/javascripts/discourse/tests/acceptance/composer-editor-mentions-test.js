import { test } from "qunit";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { setCaretPosition } from "discourse/lib/utilities";

const BACKSPACE_KEYCODE = 8;

acceptance("Composer - editor mentions", function (needs) {
  needs.user();
  needs.settings({ enable_mentions: true });

  needs.pretender((server, helper) => {
    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "user",
            name: "Some User",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "user2",
            name: "Some User",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
        ],
      });
    });
  });

  test("selecting user mentions", async function (assert) {
    await visit("/");
    await click("#create-topic");

    // Emulate user pressing backspace in the editor
    const editor = query(".d-editor-input");

    await triggerKeyEvent(".d-editor-input", "keydown", "@".charCodeAt(0));
    await fillIn(".d-editor-input", "abc @");
    await setCaretPosition(editor, 5);
    await triggerKeyEvent(".d-editor-input", "keyup", "@".charCodeAt(0));

    await triggerKeyEvent(".d-editor-input", "keydown", "u".charCodeAt(0));
    await fillIn(".d-editor-input", "abc @u");
    await setCaretPosition(editor, 6);
    await triggerKeyEvent(".d-editor-input", "keyup", "u".charCodeAt(0));

    await click(".autocomplete.ac-user .selected");

    assert.strictEqual(
      query(".d-editor-input").value,
      "abc @user ",
      "should replace mention correctly"
    );
  });

  test("selecting user mentions after deleting characters", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "abc @user a");

    // Emulate user typing `@` and `u` in the editor
    await triggerKeyEvent(".d-editor-input", "keydown", BACKSPACE_KEYCODE);
    await fillIn(".d-editor-input", "abc @user ");
    await triggerKeyEvent(".d-editor-input", "keyup", BACKSPACE_KEYCODE);

    await triggerKeyEvent(".d-editor-input", "keydown", BACKSPACE_KEYCODE);
    await fillIn(".d-editor-input", "abc @user");
    await triggerKeyEvent(".d-editor-input", "keyup", BACKSPACE_KEYCODE);

    await click(".autocomplete.ac-user .selected");

    assert.strictEqual(
      query(".d-editor-input").value,
      "abc @user ",
      "should replace mention correctly"
    );
  });

  test("selecting user mentions after deleting characters mid sentence", async function (assert) {
    await visit("/");
    await click("#create-topic");

    // Emulate user pressing backspace in the editor
    const editor = query(".d-editor-input");
    await fillIn(".d-editor-input", "abc @user 123");
    await setCaretPosition(editor, 9);

    await triggerKeyEvent(".d-editor-input", "keydown", BACKSPACE_KEYCODE);
    await fillIn(".d-editor-input", "abc @use 123");
    await triggerKeyEvent(".d-editor-input", "keyup", BACKSPACE_KEYCODE);
    await setCaretPosition(editor, 8);

    await triggerKeyEvent(".d-editor-input", "keydown", BACKSPACE_KEYCODE);
    await fillIn(".d-editor-input", "abc @us 123");
    await triggerKeyEvent(".d-editor-input", "keyup", BACKSPACE_KEYCODE);
    await setCaretPosition(editor, 7);

    await click(".autocomplete.ac-user .selected");

    assert.strictEqual(
      query(".d-editor-input").value,
      "abc @user 123",
      "should replace mention correctly"
    );
  });
});
