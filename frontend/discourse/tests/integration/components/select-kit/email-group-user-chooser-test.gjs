import { hash } from "@ember/helper";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { paste } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import pretender, { response } from "../../../helpers/create-pretender";

module(
  "Integration | Component | select-kit/email-group-user-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("pasting", async function (assert) {
      await render(<template><EmailGroupUserChooser /></template>);

      await this.subject.expand();
      await paste(".filter-input", "foo,bar");

      assert.strictEqual(this.subject.header().value(), "foo,bar");

      await paste(".filter-input", "evil,trout");
      assert.strictEqual(this.subject.header().value(), "foo,bar,evil,trout");

      await paste(".filter-input", "names with spaces");
      assert.strictEqual(
        this.subject.header().value(),
        "foo,bar,evil,trout,names,with,spaces"
      );

      await paste(".filter-input", "@osama,@sam");
      assert.strictEqual(
        this.subject.header().value(),
        "foo,bar,evil,trout,names,with,spaces,osama,sam"
      );

      await paste(".filter-input", "new\nlines");
      assert.strictEqual(
        this.subject.header().value(),
        "foo,bar,evil,trout,names,with,spaces,osama,sam,new,lines"
      );
    });

    test("excluding usernames", async function (assert) {
      const self = this;

      pretender.get("/u/search/users", () => {
        const users = [
          {
            username: "osama",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "joshua",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "sam",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
        ];
        return response({ users });
      });

      this.set("excludedUsernames", ["osama", "joshua"]);
      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash excludedUsernames=self.excludedUsernames}}
          />
        </template>
      );

      await this.subject.expand();
      await this.subject.fillInFilter("a");

      let suggestions = this.subject.displayedContent().map((item) => item.id);
      assert.deepEqual(suggestions, ["sam"]);

      this.set("excludedUsernames", ["osama"]);
      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash excludedUsernames=self.excludedUsernames}}
          />
        </template>
      );

      await this.subject.expand();
      await this.subject.fillInFilter("a");

      suggestions = this.subject
        .displayedContent()
        .map((item) => item.id)
        .sort();
      assert.deepEqual(suggestions, ["joshua", "sam"]);
    });

    test("doesn't show user status by default", async function (assert) {
      pretender.get("/u/search/users", () =>
        response({
          users: [
            {
              username: "test-user",
              status: {
                description: "off to dentist",
                emoji: "tooth",
              },
            },
          ],
        })
      );

      await render(<template><EmailGroupUserChooser /></template>);
      await this.subject.expand();
      await fillIn(".filter-input", "test-user");

      assert.dom(".user-status-message").doesNotExist();
    });

    test("shows user status if enabled", async function (assert) {
      const status = {
        description: "off to dentist",
        emoji: "tooth",
      };
      pretender.get("/u/search/users", () =>
        response({
          users: [
            {
              username: "test-user",
              status,
            },
          ],
        })
      );

      await render(
        <template><EmailGroupUserChooser @showUserStatus={{true}} /></template>
      );
      await this.subject.expand();
      await fillIn(".filter-input", "test-user");

      assert.dom(".user-status-message").exists("user status is rendered");
      assert
        .dom(".user-status-message .emoji")
        .hasAttribute("alt", status.emoji, "status emoji is correct");
      assert
        .dom(".user-status-message .user-status-message-description")
        .hasText(status.description, "status description is correct");
    });
  }
);
