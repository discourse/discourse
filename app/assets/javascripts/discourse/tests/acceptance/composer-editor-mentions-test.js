import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { setCaretPosition } from "discourse/lib/utilities";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  fakeTime,
  loggedInUser,
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
  needs.settings({
    enable_mentions: true,
    allow_uncategorized_topics: true,
  });
  needs.hooks.afterEach(() => clock?.restore());

  needs.pretender((server, helper) => {
    server.get("/t/11557.json", () => {
      const topicFixture = cloneJSON(topicFixtures["/t/130.json"]);
      topicFixture.id = 11557;
      return helper.response(topicFixture);
    });
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
            username: "johndoe",
            name: "John Doe Jr",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/j/41988e/{size}.png",
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

    await simulateKeys(".d-editor-input", "abc @u\r");

    assert
      .dom(".d-editor-input")
      .hasValue("abc @user ", "replaces mention correctly");
  });

  test("selecting user mentions after deleting characters", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await simulateKeys(".d-editor-input", "abc @user a\b\b\r");

    assert
      .dom(".d-editor-input")
      .hasValue("abc @user ", "replaces mention correctly");
  });

  test("selecting user mentions after deleting characters mid sentence", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await simulateKeys(".d-editor-input", "abc @user 123");
    await setCaretPosition(".d-editor-input", 9);
    await simulateKeys(".d-editor-input", "\b\b\r");

    assert
      .dom(".d-editor-input")
      .hasValue("abc @user 123", "replaces mention correctly");
  });

  test("shows status on search results when mentioning a user", async function (assert) {
    const timezone = loggedInUser().user_option.timezone;
    const now = moment(status.ends_at).add(-1, "hour").format();
    clock = fakeTime(now, timezone, true);

    await visit("/");
    await click("#create-topic");

    await simulateKeys(".d-editor-input", "@u");

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

    await simulateKeys(".d-editor-input", "abc @u");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["user", "user2", "user_group", "johndoe", "foo"]
    );

    await simulateKeys(".d-editor-input", "\bf");

    assert.deepEqual(
      [...queryAll(".ac-user .username")].map((e) => e.innerText),
      ["foo", "user", "user2", "johndoe"]
    );
  });

  test("shows users immediately when @ is typed in a reply", async function (assert) {
    await visit("/");
    await click(".topic-list-item .title");
    await click(".btn-primary.create");

    await simulateKeys(".d-editor-input", "abc @");

    assert.deepEqual(
      [...document.querySelectorAll(".ac-user .username")].map(
        (e) => e.innerText
      ),
      ["user_group", "user", "user2", "johndoe", "foo"]
    );
  });

  test("selecting user mentions by partial full name", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await simulateKeys(".d-editor-input", "abc @John Doe J\r");

    assert
      .dom(".d-editor-input")
      .hasValue("abc @johndoe ", "replaces full name mention correctly");
  });
});
