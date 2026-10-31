import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

const USERS = [
  {
    username: "Sam",
    name: "Sam Saffron",
    avatar_template: "/a/sam/{size}.png",
  },
  { username: "bob", name: "Bob Ross", avatar_template: "/a/bob/{size}.png" },
  { username: "alice", name: "Alice", avatar_template: "/a/alice/{size}.png" },
  {
    username: "eviltrout",
    name: "Robin Ward",
    avatar_template: "/a/evil/{size}.png",
  },
];

const GROUPS = [
  { name: "team", full_name: "The Team" },
  { name: "Support_Team", full_name: "Support_Team" },
];

const GROUP_FLAGS = [
  "include_groups",
  "include_mentionable_groups",
  "include_messageable_groups",
];

/**
 * Answers user search like the server: by `term`, or by exact `usernames` in any case, with
 * groups only when an include flag is sent. Records every request's params.
 */
function stubUserSearch({ users = USERS, groups = GROUPS } = {}) {
  const requests = [];
  pretender.get("/u/search/users", (request) => {
    const params = request.queryParams;
    requests.push(params);
    const withGroups = GROUP_FLAGS.some((flag) => params[flag] === "true");
    if (params.usernames) {
      const names = params.usernames.split(",").map((n) => n.toLowerCase());
      return response({
        users: users.filter((u) => names.includes(u.username.toLowerCase())),
        groups: withGroups
          ? groups.filter((g) => names.includes(g.name.toLowerCase()))
          : [],
      });
    }
    const term = (params.term ?? "").toLowerCase();
    const matches = (text) => text?.toLowerCase().includes(term);
    return response({
      users: users.filter((u) => matches(u.username) || matches(u.name)),
      groups: withGroups
        ? groups.filter((g) => matches(g.name) || matches(g.full_name))
        : [],
    });
  });
  return requests;
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

/** The labels of the listed options, in order. */
function optionValues() {
  return findAll("[role='option']").map((row) => row.dataset.value);
}

/** Pastes `text` into the field's query input. */
async function paste(text) {
  const clipboardData = new DataTransfer();
  clipboardData.setData("text/plain", text);
  const event = new ClipboardEvent("paste", {
    bubbles: true,
    cancelable: true,
    clipboardData,
  });
  find("[role='combobox']").dispatchEvent(event);
  await settled();
  return event;
}

module(
  "Integration | ui-kit | select | recipes | DSelectUser",
  function (hooks) {
    setupRenderingTest(hooks);

    test("searches users and draws avatar, username, then name", async function (assert) {
      const requests = stubUserSearch();

      await render(<template><DSelectUser /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("bo");

      assert.deepEqual(requests, [{ term: "bo", limit: "6" }]);
      const row = optionNamed("bob");
      assert.dom(".d-user-option__username", row).hasText("bob");
      assert.dom(".d-user-option__name", row).hasText("Bob Ross");
      assert
        .dom("img.avatar", row)
        .hasAttribute("alt", "", "the avatar doesn't repeat the name");
      assert.strictEqual(
        row.querySelector(".d-user-option").textContent.trim().indexOf("bob"),
        0,
        "the username comes first"
      );
    });

    test("lists nothing until something is typed, unless a topic or category scopes it", async function (assert) {
      const requests = stubUserSearch();
      const state = new (class {
        @tracked topicId;
      })();

      await render(
        <template><DSelectUser @topicId={{state.topicId}} /></template>
      );
      const select = new DSelect();
      await select.open();

      assert.deepEqual(requests, [], "an empty query sends nothing");
      assert.dom(".d-select__min-chars").exists();

      await select.close();
      state.topicId = 12;
      await select.open();

      assert.deepEqual(requests, [{ term: "", topic_id: "12", limit: "6" }]);
      assert.true(optionValues().length > 0, "the topic's users are listed");
    });

    test("names the control by what it offers", async function (assert) {
      const accessibleName = await loadAccessibleName();
      const state = new (class {
        @tracked groups;
        @tracked emails = false;
        @tracked multiple = false;
      })();

      await render(
        <template>
          <DSelectUser
            @emails={{state.emails}}
            @includeGroups={{state.groups}}
            @multiple={{state.multiple}}
          />
        </template>
      );
      const name = () => accessibleName(find("[role='combobox']"));

      assert.strictEqual(name(), i18n("select_user.user"));
      state.multiple = true;
      await settled();
      assert.strictEqual(name(), i18n("select_user.users"));
      state.groups = "messageable";
      await settled();
      assert.strictEqual(name(), i18n("select_user.users_or_groups"));
      state.emails = true;
      await settled();
      assert.strictEqual(name(), i18n("select_user.users_groups_or_emails"));
      state.groups = undefined;
      await settled();
      assert.strictEqual(name(), i18n("select_user.users_or_emails"));
      state.multiple = false;
      await settled();
      assert.strictEqual(name(), i18n("select_user.user_or_email"));
    });

    test("resolves held names in one request and keeps their spelling", async function (assert) {
      const requests = stubUserSearch();
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelectUser
            @includeGroups="visible"
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array "SAM" "support_team" "ghost"}}
          />
        </template>
      );

      assert.deepEqual(requests, [
        { usernames: "SAM,support_team,ghost", include_groups: "true" },
      ]);
      const chips = findAll(".d-select__chip");
      assert.dom(".d-user-option__username", chips[0]).hasText("Sam");
      assert.dom("img.avatar", chips[0]).exists("a held user shows its avatar");
      assert.dom(chips[1]).includesText("Support_Team");
      assert
        .dom(chips[2])
        .includesText("ghost", "an unknown name shows as itself");
      assert
        .dom(chips[2])
        .doesNotIncludeText(
          i18n("d_select.unresolved_value", { value: "ghost" }),
          "not as an unknown item"
        );

      const select = new DSelect();
      await select.open();
      await select.search("bob");
      await click(optionNamed("bob"));

      assert.deepEqual(
        onChange.lastCall.args[0],
        ["SAM", "support_team", "ghost", "bob"],
        "held values keep the spelling they were given"
      );
    });

    test("keeps held users listed and selected", async function (assert) {
      stubUserSearch();

      await render(
        <template>
          <DSelectUser @multiple={{true}} @value={{array "bob"}} />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("bo");

      assert.dom(optionNamed("bob")).hasAttribute("aria-selected", "true");
    });

    test("leaves excluded names and, when asked, the current user out", async function (assert) {
      stubUserSearch();
      const state = new (class {
        @tracked exclude = ["ALICE"];
      })();

      await render(
        <template>
          <DSelectUser
            @exclude={{state.exclude}}
            @excludeCurrentUser={{true}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("a");

      assert.deepEqual(
        optionValues(),
        ["Sam"],
        "Alice and the current user, Robin Ward, are left out"
      );

      state.exclude = ["sam"];
      await settled();

      assert.deepEqual(
        optionValues(),
        ["alice"],
        "a changed exclusion reloads the open list"
      );
    });

    test("emits the value and typed items, in single and multiple mode", async function (assert) {
      stubUserSearch();
      const onChange = sinon.spy();
      const state = new (class {
        @tracked value = null;
        @tracked multiple = false;
      })();
      const change = (value, items) => {
        onChange(value, items);
        state.value = value;
      };

      await render(
        <template>
          <DSelectUser
            @clearable={{true}}
            @includeGroups="visible"
            @multiple={{state.multiple}}
            @onChange={{change}}
            @value={{state.value}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("team");
      await click(optionNamed("The Team"));

      assert.strictEqual(onChange.lastCall.args[0], "team");
      assert.strictEqual(onChange.lastCall.args[1].type, "group");

      await select.clear();
      assert.strictEqual(onChange.lastCall.args[0], null);
      assert.strictEqual(onChange.lastCall.args[1], null);

      state.multiple = true;
      state.value = [];
      await settled();
      await select.open();
      await select.search("sam");
      await click(optionNamed("Sam"));

      assert.deepEqual(onChange.lastCall.args[0], ["Sam"]);
      assert.deepEqual(
        onChange.lastCall.args[1].map((item) => item.type),
        ["user"]
      );
    });

    test("offers a typed email as a row only when emails are on", async function (assert) {
      stubUserSearch();
      const onChange = sinon.spy();
      const state = new (class {
        @tracked value = [];
      })();
      const change = (value, items) => {
        onChange(value, items);
        state.value = value;
      };

      await render(
        <template>
          <DSelectUser
            @emails={{true}}
            @multiple={{true}}
            @onChange={{change}}
            @value={{state.value}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("someone@example.com");

      assert.dom(".d-email-option").hasText("someone@example.com");
      assert.dom(".d-select__option.--create").doesNotExist();
      await click(optionNamed("someone@example.com"));

      assert.deepEqual(onChange.lastCall.args[0], ["someone@example.com"]);
      assert.strictEqual(onChange.lastCall.args[1][0].type, "email");
      assert
        .dom(".d-select__chip .d-email-option .sr-only")
        .hasText(i18n("select_user.email_type"), "the chip says it's an email");
    });

    test("asks for groups in the given scope and marks group chips", async function (assert) {
      const requests = stubUserSearch();

      await render(
        <template>
          <DSelectUser
            @includeGroups="messageable"
            @multiple={{true}}
            @value={{array "team"}}
          />
        </template>
      );
      assert
        .dom(".d-select__chip .d-group-option .sr-only")
        .hasText(i18n("select_user.group_type"), "the chip says it's a group");

      const select = new DSelect();
      await select.open();
      await select.search("tea");

      assert.strictEqual(requests.at(-1).include_messageable_groups, "true");
      assert.dom(".d-group-option .d-icon-users").exists();
      assert
        .dom(".d-select__option-description", optionNamed("team"))
        .hasText("The Team", "a different full name is the description");
      assert
        .dom(".d-select__option-description", optionNamed("Support_Team"))
        .doesNotExist("a full name equal to the name isn't repeated");
    });

    test("pastes a list of names, resolved in one request", async function (assert) {
      const requests = stubUserSearch();
      const state = new (class {
        @tracked value = [];
      })();
      const change = (value) => (state.value = value);

      await render(
        <template>
          <DSelectUser
            @multiple={{true}}
            @onChange={{change}}
            @value={{state.value}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      requests.length = 0;

      const event = await paste("@sam, bob\nghost");

      assert.true(event.defaultPrevented);
      assert.deepEqual(state.value, ["sam", "bob", "ghost"]);
      assert.deepEqual(
        requests,
        [{ usernames: "sam,bob,ghost" }],
        "the pasted names are looked up together"
      );
      assert.dom(".d-select__chip img.avatar").exists({ count: 2 });
    });

    test("leaves a single name, or any paste into a single select, to the browser", async function (assert) {
      stubUserSearch();
      const state = new (class {
        @tracked multiple = true;
      })();

      await render(
        <template><DSelectUser @multiple={{state.multiple}} /></template>
      );
      const select = new DSelect();
      await select.open();

      assert.false((await paste("sam")).defaultPrevented);

      await select.close();
      state.multiple = false;
      await settled();
      await select.open();

      assert.false((await paste("sam, bob")).defaultPrevented);
    });

    test("shows a user's status only when asked", async function (assert) {
      stubUserSearch({
        users: [
          {
            username: "bob",
            name: "Bob Ross",
            avatar_template: "/a/bob/{size}.png",
            status: { emoji: "palm_tree", description: "On vacation" },
          },
        ],
      });
      const state = new (class {
        @tracked showStatus = false;
      })();

      await render(
        <template><DSelectUser @showStatus={{state.showStatus}} /></template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("bob");

      assert.dom(".d-select__option-description").doesNotExist();

      await select.close();
      state.showStatus = true;
      await settled();
      await select.open();
      await select.search("bob");

      assert.dom(".d-select__option-description").hasText("On vacation");
      assert
        .dom(".d-user-option__status img.emoji")
        .hasAttribute("alt", "", "the emoji doesn't add its code to the name");
      assert.dom("[role='option'] [role='button']").doesNotExist();
    });

    test("sends search options from the call site and from customizations", async function (assert) {
      const requests = stubUserSearch();
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forKind("select-user", (spec) =>
            spec.options((current) => ({
              searchOptions: { ...current.searchOptions, assignable: true },
            }))
          )
        )
      );

      await render(
        <template>
          <DSelectUser @searchOptions={{hash canReview=true}} />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("bob");

      assert.deepEqual(requests, [
        { term: "bob", limit: "6", can_review: "true", assignable: "true" },
      ]);
    });

    test("lists the call site's special rows first and resolves them locally", async function (assert) {
      const requests = stubUserSearch();
      const special = () => [{ id: "author", name: "Topic author" }];

      await render(
        <template>
          <DSelectUser @specialItems={{special}} @value="author" />
        </template>
      );

      assert.dom(".d-select__trigger").includesText("Topic author");
      assert.deepEqual(requests, [], "a special value is never looked up");
    });

    test("carries both legacy names, since the old choosers answered to both", async function (assert) {
      stubUserSearch();

      await render(
        <template>
          <DSelectUser class="a" />
          <DSelectUser class="b" @legacyKind="user-chooser" />
        </template>
      );

      assert.dom(".a.d-select").hasClass("user-chooser");
      assert.dom(".a.d-select").hasClass("email-group-user-chooser");
      assert.dom(".b.d-select").hasClass("user-chooser");
      assert
        .dom(".b.d-select")
        .doesNotHaveClass(
          "email-group-user-chooser",
          "a call site can narrow it"
        );
    });
  }
);
