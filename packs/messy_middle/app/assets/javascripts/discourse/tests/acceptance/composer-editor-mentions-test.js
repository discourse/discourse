import { test } from "qunit";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  fakeTime,
  loggedInUser,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { setCaretPosition } from "discourse/lib/utilities";

acceptance("Composer - editor mentions", function (needs) {
  let clock = null;
  const status = {
    emoji: "tooth",
    description: "off to dentist",
    ends_at: "2100-02-01T09:00:00.000Z",
  };

  needs.user();
  needs.settings({ enable_mentions: true, allow_uncategorized_topics: true });

  needs.hooks.afterEach(() => {
    if (clock) {
      clock.restore();
    }
  });

  needs.pretender((server, helper) => {
    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "user",
            name: "Some User",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
            status,
          },
          {
            username: "user2",
            name: "Some User",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "foo",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
        ],
        groups: [
          {
            name: "user_group",
            full_name: "Group",
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

    await triggerKeyEvent(".d-editor-input", "keydown", "@");
    await fillIn(".d-editor-input", "abc @");
    await setCaretPosition(editor, 5);
    await triggerKeyEvent(".d-editor-input", "keyup", "@");

    await triggerKeyEvent(".d-editor-input", "keydown", "U");
    await fillIn(".d-editor-input", "abc @u");
    await setCaretPosition(editor, 6);
    await triggerKeyEvent(".d-editor-input", "keyup", "U");

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
    await triggerKeyEvent(".d-editor-input", "keydown", "Backspace");
    await fillIn(".d-editor-input", "abc @user ");
    await triggerKeyEvent(".d-editor-input", "keyup", "Backspace");

    await triggerKeyEvent(".d-editor-input", "keydown", "Backspace");
    await fillIn(".d-editor-input", "abc @user");
    await triggerKeyEvent(".d-editor-input", "keyup", "Backspace");

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

    await triggerKeyEvent(".d-editor-input", "keydown", "Backspace");
    await fillIn(".d-editor-input", "abc @use 123");
    await triggerKeyEvent(".d-editor-input", "keyup", "Backspace");
    await setCaretPosition(editor, 8);

    await triggerKeyEvent(".d-editor-input", "keydown", "Backspace");
    await fillIn(".d-editor-input", "abc @us 123");
    await triggerKeyEvent(".d-editor-input", "keyup", "Backspace");
    await setCaretPosition(editor, 7);

    await click(".autocomplete.ac-user .selected");

    assert.strictEqual(
      query(".d-editor-input").value,
      "abc @user 123",
      "should replace mention correctly"
    );
  });

  test("shows status on search results when mentioning a user", async function (assert) {
    const timezone = loggedInUser().user_option.timezone;
    const now = moment(status.ends_at).add(-1, "hour").format();
    clock = fakeTime(now, timezone, true);

    await visit("/");
    await click("#create-topic");

    // emulate typing in "abc @u"
    const editor = query(".d-editor-input");
    await fillIn(".d-editor-input", "@");
    await setCaretPosition(editor, 5);
    await triggerKeyEvent(".d-editor-input", "keyup", "@");
    await fillIn(".d-editor-input", "@u");
    await setCaretPosition(editor, 6);
    await triggerKeyEvent(".d-editor-input", "keyup", "U");

    assert.ok(
      exists(`.autocomplete .emoji[title='${status.emoji}']`),
      "status emoji is shown"
    );
    assert.equal(
      query(".autocomplete .status-description").textContent.trim(),
      status.description,
      "status description is shown"
    );
    assert.equal(
      query(".autocomplete .relative-date").textContent.trim(),
      "1h",
      "status expiration time is shown"
    );
  });

  test("metadata matches are moved to the end", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn(".d-editor-input", "abc @");
    await triggerKeyEvent(".d-editor-input", "keyup", "@");
    await fillIn(".d-editor-input", "abc @u");
    await triggerKeyEvent(".d-editor-input", "keyup", "U");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["user", "user2", "user_group", "foo"]
    );

    await fillIn(".d-editor-input", "abc @");
    await triggerKeyEvent(".d-editor-input", "keyup", "@");
    await fillIn(".d-editor-input", "abc @f");
    await triggerKeyEvent(".d-editor-input", "keyup", "F");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["foo", "user_group", "user", "user2"]
    );
  });
});
