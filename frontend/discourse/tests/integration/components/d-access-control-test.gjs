import { tracked } from "@glimmer/tracking";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DAccessControl from "discourse/ui-kit/d-access-control";
import { i18n } from "discourse-i18n";

// A non-automatic group, plus the "logged_in_users" auto group (id: 5) which is one of
// the groups that defaults to view-only access when added.
const GROUPS = [
  {
    id: 42,
    name: "team_a",
    full_name: "Team A",
    automatic: false,
    flair_url: "users",
    flair_bg_color: "CC0000",
    flair_color: "FFFFFF",
  },
  {
    id: AUTO_GROUPS.logged_in_users.id,
    name: "logged_in_users",
    full_name: "Logged In Users",
    automatic: true,
  },
  {
    id: AUTO_GROUPS.trust_level_0.id,
    name: "trust_level_0",
    full_name: "Trust level 0",
    automatic: true,
  },
];

// Builds a controlled-component wrapper: `onChange` writes the next acl back into
// tracked state so the component re-renders the way it would in a real parent.
function controlledState(initialAcl = []) {
  return new (class {
    @tracked acl = initialAcl;
    onChangeCalls = [];

    onChange = (next) => {
      this.onChangeCalls.push(next);
      this.acl = next;
    };
  })();
}

module("Integration | Component | DAccessControl", function (hooks) {
  setupRenderingTest(hooks);

  test("adds a group with the default permission via the preloaded grantee chooser", async function (assert) {
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .doesNotExist("starts with no acl rows");

    await click(".d-access-control__add");

    const chooser = selectKit(".d-access-control__chooser");
    await chooser.expand();
    await chooser.expand();

    assert
      .dom(".d-access-control__chooser .select-kit-row[data-value='group:42']")
      .exists("availableGroups are listed in the chooser");

    await chooser.selectRowByValue("group:42");

    assert.strictEqual(
      state.onChangeCalls.length,
      1,
      "onChange is called when a group is chosen"
    );

    const [added] = state.onChangeCalls[0];
    assert.strictEqual(added.id, 42, "adds the chosen group");
    assert.strictEqual(added.type, "group", "marks the entry as a group");
    assert.strictEqual(
      added.display_name,
      "Team A",
      "sets the display name from the chosen group"
    );
    assert.strictEqual(added.name, "team_a", "keeps the group name for flair");
    assert.strictEqual(
      added.flair_url,
      "users",
      "keeps the flair URL for group flair rendering"
    );
    assert.strictEqual(
      added.flair_bg_color,
      "CC0000",
      "keeps the flair background color for group flair rendering"
    );
    assert.strictEqual(
      added.flair_color,
      "FFFFFF",
      "keeps the flair color for group flair rendering"
    );
    assert.strictEqual(
      added.permission,
      "edit",
      "applies the default edit permission for a regular group"
    );

    assert
      .dom(".d-access-control__row .d-access-control__group-name")
      .hasText("Team A", "renders the newly added group row");
    assert
      .dom(".d-access-control__row .avatar-flair")
      .hasAttribute("title", "team_a", "renders the selected group's flair");
  });

  test("a read-only default group is added with the view permission", async function (assert) {
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await click(".d-access-control__add");

    const chooser = selectKit(".d-access-control__chooser");
    await chooser.expand();
    await chooser.expand();
    await chooser.selectRowByValue(`group:${AUTO_GROUPS.trust_level_0.id}`);

    const [added] = state.onChangeCalls[0];
    assert.strictEqual(
      added.permission,
      "view",
      "applies the default view permission for a read-only default group"
    );
    assert
      .dom(".d-access-control__row .d-icon-user-group")
      .exists("renders the generic group icon when the group has no flair");
  });

  test("searches grantees using the access control search endpoint", async function (assert) {
    pretender.get("/access-control/grantees/search", (request) => {
      assert.strictEqual(
        request.queryParams.term,
        "ada",
        "passes the filter term to the search endpoint"
      );

      return response({
        users: [
          {
            id: 7,
            username: "ada",
            name: "Ada Lovelace",
            avatar_template: "/letter_avatar_proxy/v4/letter/a/{size}.png",
          },
        ],
        groups: [],
      });
    });

    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @aclTarget="TestTarget"
          @onChange={{state.onChange}}
        />
      </template>
    );

    await click(".d-access-control__add");

    const chooser = selectKit(".d-access-control__chooser");
    await chooser.expand();
    await chooser.fillInFilter("ada");
    await chooser.selectRowByValue("user:7");

    const [added] = state.onChangeCalls[0];
    assert.strictEqual(added.id, 7, "adds the chosen user");
    assert.strictEqual(added.type, "user", "marks the entry as a user");
    assert.strictEqual(
      added.display_name,
      "Ada Lovelace",
      "sets the display name from the chosen user"
    );
    assert.strictEqual(
      added.username,
      "ada",
      "keeps the username for avatar rendering"
    );
    assert.strictEqual(
      added.name,
      "Ada Lovelace",
      "keeps the name for avatar rendering"
    );
    assert.strictEqual(
      added.avatar_template,
      "/letter_avatar_proxy/v4/letter/a/{size}.png",
      "keeps the avatar template for avatar rendering"
    );
    assert.strictEqual(
      added.permission,
      "edit",
      "applies the default edit permission for a user"
    );
  });

  test("transformPermissionOptions can change descriptions and add options", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
    ]);

    const transformPermissionOptions = (permissions) => [
      ...permissions.map((permission) =>
        permission.id === "view"
          ? { ...permission, description: "Custom view description" }
          : permission
      ),
      { id: "juggler", level: 3, name: "Juggler", description: "Full control" },
    ];

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
          @transformPermissionOptions={{transformPermissionOptions}}
        />
      </template>
    );

    const permission = selectKit(".d-access-control__permission");
    await permission.expand();

    assert.strictEqual(
      permission.rowByValue("view").description(),
      "Custom view description",
      "uses the transformed description for an existing option"
    );

    assert.true(
      permission.rowByValue("juggler").exists(),
      "renders the added permission option"
    );
    assert.strictEqual(
      permission.rowByValue("juggler").label(),
      "Juggler",
      "the added option keeps its name"
    );
  });

  test("loads multiple existing acl groups with their permissions", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
      {
        type: "group",
        id: 1001,
        permission: "edit",
        display_name: "Another Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .exists({ count: 2 }, "renders a row per acl entry");

    const rows = [...document.querySelectorAll(".d-access-control__row")];

    assert
      .dom(".d-access-control__group-name", rows[0])
      .hasText("Another Group", "renders the first group name");
    assert.strictEqual(
      rows[0].querySelector(".select-kit-header").dataset.value,
      "edit",
      "loads the first group's permission"
    );

    assert
      .dom(".d-access-control__group-name", rows[1])
      .hasText("Some Group", "renders the second group name");
    assert.strictEqual(
      rows[1].querySelector(".select-kit-header").dataset.value,
      "view",
      "loads the second group's permission"
    );
  });

  test("the Remove option removes the acl row", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
      {
        type: "group",
        id: 1001,
        permission: "edit",
        display_name: "Another Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert.dom(".d-access-control__row").exists({ count: 2 });

    // selectKit() targets the first matching dropdown, i.e. the "Some Group" row.
    const permission = selectKit(".d-access-control__permission");
    await permission.expand();
    await permission.selectRowByValue("remove");

    assert
      .dom(".d-access-control__row")
      .exists({ count: 1 }, "removes the row whose permission was removed");
    assert
      .dom(".d-access-control__group-name")
      .hasText("Some Group", "keeps the remaining row");
  });

  test("calls the onChange arg when a permission changes", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const permission = selectKit(".d-access-control__permission");
    await permission.expand();
    await permission.selectRowByValue("edit");

    assert.strictEqual(
      state.onChangeCalls.length,
      1,
      "onChange is called once"
    );
    assert.strictEqual(
      state.onChangeCalls[0][0].permission,
      "edit",
      "onChange receives the acl with the updated permission"
    );
  });

  test("uses the default permission option labels", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const permission = selectKit(".d-access-control__permission");
    await permission.expand();

    assert.strictEqual(
      permission.rowByValue("view").label(),
      i18n("access_control.manage.access_permission_viewer"),
      "renders the default viewer option"
    );
    assert.strictEqual(
      permission.rowByValue("edit").label(),
      i18n("access_control.manage.access_permission_editor"),
      "renders the default editor option"
    );
  });

  test("filters banned permissions for the matching grantee", async function (assert) {
    this.site.access_control = {
      banned_acl: {
        TestTarget: [
          { type: "group", id: 42, permission: "edit" },
          { type: "group", id: 42, permission: "manage" },
          { type: "group", id: 999, permission: "view" },
        ],
      },
    };
    const state = controlledState([
      {
        type: "group",
        id: 42,
        permission: "view",
        display_name: "Team A",
      },
    ]);

    const transformPermissionOptions = (permissions) => [
      ...permissions,
      { id: "manage", level: 3, name: "Manager", description: "Full control" },
    ];

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @aclTarget="TestTarget"
          @onChange={{state.onChange}}
          @transformPermissionOptions={{transformPermissionOptions}}
        />
      </template>
    );

    const permission = selectKit(".d-access-control__permission");
    await permission.expand();

    assert.true(
      permission.rowByValue("view").exists(),
      "keeps permissions not banned for this grantee"
    );
    assert.false(
      permission.rowByValue("edit").exists(),
      "removes a banned default permission"
    );
    assert.false(
      permission.rowByValue("manage").exists(),
      "removes a banned transformed permission"
    );
    assert.true(
      permission.rowByValue("remove").exists(),
      "keeps the remove action"
    );
  });

  test("puts mandatory permissions at the top of the rows and disables removing the permission", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
        mandatory: true,
      },
      {
        type: "group",
        id: 1001,
        permission: "edit",
        display_name: "Another Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const rows = [...document.querySelectorAll(".d-access-control__row")];
    assert.dom(rows[0]).hasClass("--mandatory", "the mandatory row is first");
    assert
      .dom(
        rows[0].querySelector(
          ".d-access-control__permission.dropdown-select-box"
        )
      )
      .hasClass(
        "is-disabled",
        "the mandatory row's permission select is disabled"
      );
  });

  test("sorts rows by mandatory status, type, and name", async function (assert) {
    const state = controlledState([
      {
        type: "user",
        id: 1,
        permission: "edit",
        display_name: "Zoe User",
        mandatory: true,
      },
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Alpha Group",
        mandatory: true,
      },
      {
        type: "user",
        id: 2,
        permission: "edit",
        display_name: "Aaron User",
      },
      {
        type: "group",
        id: 1001,
        permission: "edit",
        display_name: "Beta Group",
      },
      {
        type: "group",
        id: 1002,
        permission: "view",
        display_name: "Apple Group",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert.deepEqual(
      findAll(".d-access-control__group-name").map((row) =>
        row.textContent.trim()
      ),
      ["Alpha Group", "Zoe User", "Apple Group", "Beta Group", "Aaron User"],
      "sorts mandatory rows by name, then groups by name, then users by name"
    );
    assert.deepEqual(
      findAll(".d-access-control__row").map((row) => row.dataset.rowType),
      ["group", "user", "group", "group", "user"],
      "keeps regular groups before regular users"
    );
  });

  test("injects mandatory acl rows for the target", async function (assert) {
    this.site.access_control = {
      mandatory_acl: {
        TestTarget: [{ type: "group", id: 42, permission: "edit" }],
      },
    };
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @aclTarget="TestTarget"
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .exists({ count: 1 }, "renders the mandatory row");
    assert
      .dom(".d-access-control__row")
      .hasClass("--mandatory", "marks the row as mandatory");
    assert
      .dom(".d-access-control__group-name")
      .hasText("Team A", "renders the mandatory group's name");

    assert.strictEqual(
      document.querySelector(".d-access-control__permission .select-kit-header")
        .dataset.value,
      "edit",
      "uses the mandatory permission"
    );
    assert.strictEqual(
      state.onChangeCalls.length,
      0,
      "does not notify the parent during render"
    );
  });

  test("mandatory acl replaces an existing row for the same group", async function (assert) {
    this.site.access_control = {
      mandatory_acl: {
        TestTarget: [{ type: "group", id: 42, permission: "edit" }],
      },
    };
    const state = controlledState([
      {
        type: "group",
        id: 42,
        permission: "view",
        display_name: "Team A",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @groups={{GROUPS}}
          @acl={{state.acl}}
          @aclTarget="TestTarget"
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .exists({ count: 1 }, "does not render a duplicate group row");

    assert.strictEqual(
      document.querySelector(".d-access-control__permission .select-kit-header")
        .dataset.value,
      "edit",
      "uses the mandatory permission"
    );
  });
});
