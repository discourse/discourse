import { render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import LiveRegions from "discourse/components/a11y/live-regions";
import ReviewableNoteForm from "discourse/components/reviewable/note-form";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import DMenus from "discourse/float-kit/components/d-menus";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | Reviewable | NoteForm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_mentions = true;
    this.reviewable = { id: 1 };
    this.toasts = this.owner.lookup("service:toasts");
  });

  test("autocompletes all users and submits the completed mention", async function (assert) {
    let submittedContent;
    pretender.get("/u/search/users", (request) => {
      assert.strictEqual(
        request.queryParams.term,
        "alex",
        "searches the typed term"
      );
      assert.strictEqual(
        request.queryParams.include_groups,
        "false",
        "does not include groups"
      );
      assert.strictEqual(
        request.queryParams.groups,
        undefined,
        "does not restrict results to staff groups"
      );
      return response({
        users: [
          {
            username: "alex",
            name: "Alex",
            avatar_template: "/images/avatar.png",
            moderator: true,
          },
          {
            username: "alex_regular",
            name: "Alex Regular",
            avatar_template: "/images/avatar.png",
            moderator: false,
          },
        ],
      });
    });
    pretender.post("/review/1/notes", (request) => {
      submittedContent = request.requestBody;
      return response({ id: 2, unnotified_usernames: [] });
    });

    await render(
      <template>
        <ReviewableNoteForm @reviewable={{this.reviewable}} />
        <DMenus />
      </template>
    );

    await form().field("content").fillIn("Hello @alex");
    await triggerKeyEvent("textarea", "keyup", 88);

    assert
      .dom(".ac-user .username")
      .exists({ count: 2 }, "offers staff and regular users");
    await triggerKeyEvent("textarea", "keydown", "Enter");

    assert
      .dom("textarea")
      .hasValue("Hello @alex ", "inserts the selected mention");
    assert.dom(".ac-user").doesNotExist("closes the autocomplete");
    await form().submit();

    assert.strictEqual(
      new URLSearchParams(submittedContent).get("reviewable_note[content]"),
      "Hello @alex",
      "updates FormKit with the completed mention"
    );
    assert.dom("textarea").hasValue("", "clears the saved note");
  });

  test("autocompletes mentions inside literal code syntax", async function (assert) {
    pretender.get("/u/search/users", () =>
      response({
        users: [{ username: "alex", avatar_template: "/images/avatar.png" }],
      })
    );

    await render(
      <template>
        <ReviewableNoteForm @reviewable={{this.reviewable}} />
        <DMenus />
      </template>
    );

    await form().field("content").fillIn("```\n@alex");
    await triggerKeyEvent("textarea", "keyup", 88);
    assert
      .dom(".ac-user .username")
      .hasText("alex", "offers mentions in plaintext code syntax");

    await triggerKeyEvent("textarea", "keydown", "Enter");
    assert
      .dom("textarea")
      .hasValue("```\n@alex ", "inserts the completed mention");
  });

  test("does not autocomplete when mentions are disabled", async function (assert) {
    this.siteSettings.enable_mentions = false;
    await render(
      <template>
        <ReviewableNoteForm @reviewable={{this.reviewable}} />
        <DMenus />
      </template>
    );

    await form().field("content").fillIn("@alex");
    await triggerKeyEvent("textarea", "keyup", 88);

    assert.dom(".ac-user").doesNotExist("respects the mentions site setting");
  });

  for (const usernames of [
    ["regular_user"],
    ["regular_user", "another_user"],
  ]) {
    test(`warns after saving about ${usernames.length} inaccessible mentions`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      pretender.post("/review/1/notes", () =>
        response({
          id: 2,
          unnotified_usernames: usernames,
        })
      );

      await render(
        <template>
          <ReviewableNoteForm @reviewable={{this.reviewable}} />
          {{#each this.toasts.activeToasts as |toast|}}
            <DDefaultToast @data={{toast.options.data}} />
          {{/each}}
          <LiveRegions />
        </template>
      );
      await form()
        .field("content")
        .fillIn(usernames.map((username) => `@${username}`).join(" "));
      await form().submit();

      assert.dom(".fk-d-default-toast__message").hasText(
        i18n("review.notes.mentions_not_notified", {
          count: usernames.length,
          usernames: usernames.map((username) => `@${username}`).join(", "),
        }),
        "explains that users without reviewable access will not be notified"
      );
      assert
        .dom(".fk-d-default-toast.-warning")
        .exists("shows a warning toast");
      assert.dom("#a11y-announcements-polite").hasText(
        i18n("review.notes.mentions_not_notified", {
          count: usernames.length,
          usernames: usernames.map((username) => `@${username}`).join(", "),
        }),
        "announces the warning to screen readers"
      );
      assert.dom("textarea").hasValue("", "still saves the note successfully");
    });
  }

  test("does not warn when all mentioned users can access the review queue", async function (assert) {
    pretender.post("/review/1/notes", () =>
      response({
        id: 2,
        unnotified_usernames: [],
      })
    );

    await render(
      <template>
        <ReviewableNoteForm @reviewable={{this.reviewable}} />
        {{#each this.toasts.activeToasts as |toast|}}
          <DDefaultToast @data={{toast.options.data}} />
        {{/each}}
      </template>
    );
    await form().field("content").fillIn("@moderator");
    await form().submit();

    assert
      .dom(".fk-d-default-toast")
      .doesNotExist("does not show an unnecessary warning");
  });
});
