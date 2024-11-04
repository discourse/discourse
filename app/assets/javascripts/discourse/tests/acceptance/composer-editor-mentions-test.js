import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { setCaretPosition } from "discourse/lib/utilities";
import {
  acceptance,
  fakeTime,
  loggedInUser,
  query,
  queryAll,
  simulateKeys,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - editor mentions", function (needs) {
  let clock = null;

  const status = {
    emoji: "tooth",
    description: "off to dentist",
    ends_at: "2100-02-01T09:00:00.000Z",
  };

  needs.user();
  needs.settings({ enable_mentions: true, allow_uncategorized_topics: true });
  needs.hooks.afterEach(() => clock?.restore());

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

    const editor = query(".d-editor-input");

    await simulateKeys(editor, "abc @u\r");

    assert.strictEqual(
      editor.value,
      "abc @user ",
      "should replace mention correctly"
    );
  });

  test("selecting user mentions after deleting characters", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const editor = query(".d-editor-input");

    await simulateKeys(editor, "abc @user a\b\b\r");

    assert.strictEqual(
      editor.value,
      "abc @user ",
      "should replace mention correctly"
    );
  });

  test("selecting user mentions after deleting characters mid sentence", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const editor = query(".d-editor-input");

    await simulateKeys(editor, "abc @user 123");
    await setCaretPosition(editor, 9);
    await simulateKeys(editor, "\b\b\r");

    assert.strictEqual(
      editor.value,
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

    const editor = query(".d-editor-input");

    await simulateKeys(editor, "@u");

    assert
      .dom(`.autocomplete .emoji[alt='${status.emoji}']`)
      .exists("status emoji is shown");

    assert
      .dom(".autocomplete .user-status-message-description")
      .hasText(status.description, "status description is shown");
  });

  test("metadata matches are moved to the end", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const editor = query(".d-editor-input");

    await simulateKeys(editor, "abc @u");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["user", "user2", "user_group", "foo"]
    );

    await simulateKeys(editor, "\bf");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["foo", "user_group", "user", "user2"]
    );
  });
});
