import { hash } from "@ember/helper";
import { fillIn, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { paste } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import pretender, { response } from "../../../helpers/create-pretender";

module(
  "Integration | Component | SelectKit | EmailGroupUserChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("renders group results with group name and full name", async function (assert) {
      this.set("defaultSearchResults", [
        {
          name: "team_a",
          full_name: "Team A",
          isGroup: true,
        },
      ]);

      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash
              customSearchOptions=(hash
                defaultSearchResults=this.defaultSearchResults
              )
            }}
          />
        </template>
      );

      await this.subject.expand();

      assert
        .dom(".email-group-user-chooser--group")
        .hasClass("--group-name-first", "applies the group-name-first style");
      assert
        .dom(".email-group-user-chooser--group .identifier")
        .hasText("team_a", "renders the group name as the identifier");
      assert
        .dom(".email-group-user-chooser--group .name")
        .hasText("Team A", "renders the full group name as the label");
    });

    test("prioritizeGroupFullNameOrdering renders the full name before the group name", async function (assert) {
      this.set("defaultSearchResults", [
        {
          name: "team_a",
          full_name: "Team A Full Name",
          isGroup: true,
        },
      ]);

      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash
              prioritizeGroupFullNameOrdering=true
              customSearchOptions=(hash
                defaultSearchResults=this.defaultSearchResults
              )
            }}
          />
        </template>
      );

      await this.subject.expand();

      const groupRow = find(".email-group-user-chooser--group");

      assert
        .dom(groupRow)
        .hasClass(
          "--group-full-name-first",
          "applies the full-name-first style"
        );
      assert.deepEqual(
        [...groupRow.querySelectorAll("span")].map((row) =>
          row.textContent.trim()
        ),
        ["Team A Full Name", "team_a"],
        "renders the full name before the group name"
      );
    });

    test("excludeGroupNameWhenMatchingFullName hides a redundant group name", async function (assert) {
      this.set("defaultSearchResults", [
        {
          name: "team_a",
          full_name: "Team A",
          isGroup: true,
        },
      ]);

      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash
              excludeGroupNameWhenMatchingFullName=true
              customSearchOptions=(hash
                defaultSearchResults=this.defaultSearchResults
              )
            }}
          />
        </template>
      );

      await this.subject.expand();

      assert
        .dom(".email-group-user-chooser--group .identifier")
        .doesNotExist("hides the equivalent group name");
      assert
        .dom(".email-group-user-chooser--group .name")
        .hasText("Team A", "keeps the full group name visible");
    });

    test("prioritizeUserNameOrdering can render the name before username", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      this.set("defaultSearchResults", [
        {
          username: "ada",
          name: "Ada Lovelace",
          isUser: true,
        },
      ]);

      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash
              prioritizeUserNameOrdering=true
              customSearchOptions=(hash
                defaultSearchResults=this.defaultSearchResults
              )
            }}
          />
        </template>
      );

      await this.subject.expand();

      const userRow = find(".email-group-user-chooser--user");

      assert
        .dom(userRow)
        .hasClass("--name-first", "applies the name-first row style");
      assert.deepEqual(
        [...userRow.querySelectorAll("span")].map((row) =>
          row.textContent.trim()
        ),
        ["Ada Lovelace", "ada"],
        "renders name before username"
      );
    });

    test("prioritize_username_in_ux keeps username first", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      this.set("defaultSearchResults", [
        {
          username: "ada",
          name: "Ada Lovelace",
          isUser: true,
        },
      ]);

      await render(
        <template>
          <EmailGroupUserChooser
            @options={{hash
              prioritizeUserNameOrdering=true
              customSearchOptions=(hash
                defaultSearchResults=this.defaultSearchResults
              )
            }}
          />
        </template>
      );

      await this.subject.expand();

      const userRow = find(".email-group-user-chooser--user");

      assert
        .dom(userRow)
        .hasClass("--username-first", "keeps the username-first row style");
      assert.deepEqual(
        [...userRow.querySelectorAll("span")].map((row) =>
          row.textContent.trim()
        ),
        ["ada", "Ada Lovelace"],
        "renders username before name"
      );
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
            @options={{hash excludedUsernames=this.excludedUsernames}}
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
            @options={{hash excludedUsernames=this.excludedUsernames}}
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
