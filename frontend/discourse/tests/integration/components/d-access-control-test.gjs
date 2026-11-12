import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DAccessControl from "discourse/ui-kit/d-access-control";
import DAccessControlField from "discourse/ui-kit/d-access-control-field";
import { i18n } from "discourse-i18n";

// A non-automatic group, plus the "logged_in_users" auto group (id: 5) which is one of
// the groups that defaults to view-only access when added.
const GROUPS = [
  {
    id: 42,
    name: "team_a",
    full_name: "Team A",
    automatic: false,
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

const aclTarget = {
  type: "TestTarget",
  id: 123,
  name: "Test Target",
};

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

function permissionOptionSelector(permission) {
  return `.d-access-control__permission-option[data-permission-id="${permission}"]`;
}

async function expandPermissionMenu(rowSelector = ".d-access-control__row") {
  await click(`${rowSelector} .d-access-control__permission`);
}

async function selectPermission(permission, rowSelector) {
  await expandPermissionMenu(rowSelector);
  await click(permissionOptionSelector(permission));
}

function permissionOptionLabel(permission) {
  return `${permissionOptionSelector(permission)} .d-access-control__permission-label`;
}

function permissionOptionDescription(permission) {
  return `${permissionOptionSelector(
    permission
  )} .d-access-control__permission-description`;
}

function rowNames() {
  return findAll(".d-access-control__item-name").map((row) =>
    [...row.childNodes]
      .find(
        (node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim()
      )
      .textContent.trim()
  );
}

module("Integration | Component | DAccessControl", function (hooks) {
  setupRenderingTest(hooks);

  test("hydrates missing group and user display names", async function (assert) {
    const state = controlledState([
      { type: "group", id: 42, permission: "edit" },
      {
        type: "user",
        id: 7,
        username: "alice",
        name: "alice",
        display_name: "",
        permission: "view",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(
        '.d-access-control__row[data-row-type="group"][data-row-id="42"] .d-access-control__item-name'
      )
      .hasText("Team A");
    assert
      .dom(
        '.d-access-control__row[data-row-type="user"][data-row-id="7"] .d-access-control__item-name'
      )
      .hasText("alice");
  });

  test("renders additional rows without fixed ACL entries", async function (assert) {
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        >
          <:additionalRows>
            <div class="d-access-control__row">Additional access</div>
          </:additionalRows>
        </DAccessControl>
      </template>
    );

    assert
      .dom(".d-access-control__rows")
      .hasText(
        "Additional access",
        "keeps additional access inside the ACL list"
      );
  });

  test("adds a group with the default permission via the preloaded grantee chooser", async function (assert) {
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .doesNotExist("starts with no acl rows");

    const chooser = selectKit(".d-access-control__chooser");
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
    assert.strictEqual(
      added.permission,
      "edit",
      "applies the default edit permission for a regular group"
    );

    assert
      .dom(".d-access-control__row .d-access-control__item-name")
      .hasText("Team A", "renders the newly added group row");
    assert
      .dom(".d-access-control__row .d-icon-user-group")
      .exists("renders the generic group icon");
  });

  test("a read-only default group is added with the view permission", async function (assert) {
    const state = controlledState();

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const chooser = selectKit(".d-access-control__chooser");
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
          @acl={{state.acl}}
          @aclTarget={{aclTarget}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const chooser = selectKit(".d-access-control__chooser");
    await chooser.expand();
    await chooser.fillInFilter("ada");
    await chooser.selectRowByValue("user:7");

    const [added] = state.onChangeCalls[0];
    assert.strictEqual(added.id, 7, "adds the chosen user");
    assert.strictEqual(added.type, "user", "marks the entry as a user");
    assert.strictEqual(
      added.display_name,
      "ada",
      "sets the display name from the site setting fallback"
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

  test("sorts newly selected users by name while respecting the display name setting", async function (assert) {
    const displayNameOnPosts = this.siteSettings.display_name_on_posts;
    const prioritizeUsernameInUx = this.siteSettings.prioritize_username_in_ux;
    this.siteSettings.display_name_on_posts = false;
    this.siteSettings.prioritize_username_in_ux = true;

    pretender.get("/access-control/grantees/search", () => {
      return response({
        users: [
          {
            id: 7,
            username: "edgar",
            name: "Edgar Allan Poe",
            avatar_template: "/letter_avatar_proxy/v4/letter/e/{size}.png",
          },
        ],
        groups: [],
      });
    });

    try {
      const state = controlledState([
        {
          type: "group",
          id: 999,
          permission: "edit",
          display_name: "Staff",
          mandatory: false,
        },
        {
          type: "user",
          id: 2,
          permission: "edit",
          display_name: "Aaron User",
          mandatory: false,
        },
        {
          type: "user",
          id: 3,
          permission: "edit",
          display_name: "Marco Bianchi",
          mandatory: false,
        },
        {
          type: "user",
          id: 4,
          permission: "edit",
          display_name: "Zoe User",
          mandatory: false,
        },
      ]);

      await render(
        <template>
          <DAccessControl
            @acl={{state.acl}}
            @aclTarget={{aclTarget}}
            @groups={{GROUPS}}
            @onChange={{state.onChange}}
          />
        </template>
      );

      const chooser = selectKit(".d-access-control__chooser");
      await chooser.expand();
      await chooser.fillInFilter("edgar");
      await chooser.selectRowByValue("user:7");

      const added = state.onChangeCalls[0].find(
        (entry) => entry.type === "user" && entry.id === 7
      );
      assert.strictEqual(
        added.display_name,
        "edgar",
        "uses the username as the display name when names are not prioritized"
      );
      assert.strictEqual(
        added.sort_name,
        "Edgar Allan Poe",
        "keeps the user's name as the sort key"
      );
      assert.deepEqual(
        rowNames(),
        ["Staff", "Aaron User", "edgar", "Marco Bianchi", "Zoe User"],
        "inserts the selected user according to the user's name"
      );
    } finally {
      this.siteSettings.display_name_on_posts = displayNameOnPosts;
      this.siteSettings.prioritize_username_in_ux = prioritizeUsernameInUx;
    }
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
      {
        id: "juggler",
        level: 3,
        name: "Juggler",
        description: "Full control",
      },
    ];

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
          @transformPermissionOptions={{transformPermissionOptions}}
        />
      </template>
    );

    await expandPermissionMenu();

    assert
      .dom(permissionOptionDescription("view"))
      .hasText(
        "Custom view description",
        "uses the transformed description for an existing option"
      );

    assert
      .dom(permissionOptionSelector("juggler"))
      .exists("renders the added permission option");
    assert
      .dom(permissionOptionLabel("juggler"))
      .hasText("Juggler", "the added option keeps its name");
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
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .exists({ count: 2 }, "renders a row per acl entry");

    const rows = [...document.querySelectorAll(".d-access-control__row")];

    assert
      .dom(".d-access-control__item-name", rows[0])
      .hasText("Another Group", "renders the first group name");
    assert
      .dom(".d-access-control__permission", rows[0])
      .hasText(
        i18n("access_control.manage.access_permission_editor"),
        "loads the first group's permission"
      );

    assert
      .dom(".d-access-control__item-name", rows[1])
      .hasText("Some Group", "renders the second group name");
    assert
      .dom(".d-access-control__permission", rows[1])
      .hasText(
        i18n("access_control.manage.access_permission_viewer"),
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
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert.dom(".d-access-control__row").exists({ count: 2 });

    await selectPermission("remove");

    assert
      .dom(".d-access-control__row")
      .exists({ count: 1 }, "removes the row whose permission was removed");
    assert
      .dom(".d-access-control__item-name")
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
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await selectPermission("edit");

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
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await expandPermissionMenu();

    assert
      .dom(permissionOptionLabel("view"))
      .hasText(
        i18n("access_control.manage.access_permission_viewer"),
        "renders the default viewer option"
      );
    assert
      .dom(permissionOptionLabel("edit"))
      .hasText(
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
      {
        id: "manage",
        level: 3,
        name: "Manager",
        description: "Full control",
      },
    ];

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @aclTarget={{aclTarget}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
          @transformPermissionOptions={{transformPermissionOptions}}
        />
      </template>
    );

    await expandPermissionMenu();

    assert
      .dom(permissionOptionSelector("view"))
      .exists("keeps permissions not banned for this grantee");
    assert
      .dom(permissionOptionSelector("edit"))
      .doesNotExist("removes a banned default permission");
    assert
      .dom(permissionOptionSelector("manage"))
      .doesNotExist("removes a banned transformed permission");
    assert
      .dom(permissionOptionSelector("remove"))
      .exists("keeps the remove action");
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
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const rows = [...document.querySelectorAll(".d-access-control__row")];
    assert.dom(rows[0]).hasClass("--mandatory", "the mandatory row is first");
    assert
      .dom(".d-access-control__permission", rows[0])
      .isDisabled("the mandatory row's permission select is disabled");
  });

  test("renders an owner after mandatory rows without a mandatory badge when ownership cannot be managed", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Alpha Group",
        mandatory: true,
      },
      {
        type: "user",
        id: 7,
        permission: "owner",
        username: "martin",
        name: "Martin Brennan",
        display_name: "martin",
        avatar_template: "/letter_avatar_proxy/v4/letter/m/{size}.png",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    const ownerRow =
      '.d-access-control__row[data-row-type="user"][data-row-id="7"]';
    const rows = findAll(".d-access-control__row");

    assert
      .dom(rows[0])
      .hasAttribute("data-row-id", "999", "renders the mandatory row first");
    assert
      .dom(rows[1])
      .hasAttribute(
        "data-row-id",
        "7",
        "renders the owner after mandatory rows"
      );
    assert.dom(ownerRow).hasClass("--owner", "identifies the row as the owner");
    assert
      .dom(ownerRow)
      .doesNotHaveClass(
        "--mandatory",
        "does not identify the owner as mandatory"
      );
    assert
      .dom(`${ownerRow} .d-access-control__item-name`)
      .includesText("martin", "renders the owner's identity");
    assert.dom(`${ownerRow} .avatar`).exists("renders the owner's avatar");
    assert
      .dom(`${ownerRow} .d-access-control__tooltip`)
      .doesNotExist("does not show a mandatory badge for the owner");
    assert
      .dom(`${ownerRow} .d-access-control__permission`)
      .hasText(
        i18n("access_control.manage.access_permission_owner"),
        "labels the permission as Owner"
      )
      .isDisabled("prevents changing or removing the owner");
  });

  test("offers only Owner and Remove for an owner manager", async function (assert) {
    const state = controlledState([
      {
        type: "user",
        id: 7,
        permission: "owner",
        username: "martin",
        display_name: "martin",
      },
    ]);
    const ownerRow =
      '.d-access-control__row[data-row-type="user"][data-row-id="7"]';

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @aclTarget={{aclTarget}}
          @canManageOwners={{true}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(`${ownerRow} .d-access-control__permission`)
      .isEnabled("allows ownership management");

    await expandPermissionMenu(ownerRow);

    assert
      .dom(permissionOptionSelector("owner"))
      .exists("keeps the current Owner option");
    assert.dom(permissionOptionDescription("owner")).hasText(
      i18n("access_control.manage.access_permission_owner_description", {
        target: aclTarget.name,
      }),
      "describes the owner's control over the target"
    );
    assert
      .dom(permissionOptionSelector("remove"))
      .exists("offers the Remove action");
    assert
      .dom(permissionOptionSelector("view"))
      .doesNotExist("does not allow downgrading the owner to Viewer");
    assert
      .dom(permissionOptionSelector("edit"))
      .doesNotExist("does not allow downgrading the owner to Editor");
  });

  test("offers ownership only for user rows when ownership can be managed", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
      {
        type: "user",
        id: 7,
        permission: "edit",
        username: "martin",
        display_name: "martin",
      },
    ]);
    const groupRow =
      '.d-access-control__row[data-row-type="group"][data-row-id="999"]';
    const userRow =
      '.d-access-control__row[data-row-type="user"][data-row-id="7"]';

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @canManageOwners={{true}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await expandPermissionMenu(userRow);

    assert
      .dom(permissionOptionSelector("owner"))
      .exists("offers Owner for a user");

    await expandPermissionMenu(userRow);
    await expandPermissionMenu(groupRow);

    assert
      .dom(permissionOptionSelector("owner"))
      .doesNotExist("does not offer Owner for a group");
  });

  test("does not offer ownership for user rows on a new target", async function (assert) {
    const state = controlledState([
      {
        type: "user",
        id: 7,
        permission: "edit",
        username: "martin",
        display_name: "martin",
      },
    ]);
    const userRow =
      '.d-access-control__row[data-row-type="user"][data-row-id="7"]';

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @canManageOwners={{true}}
          @groups={{GROUPS}}
          @isNew={{true}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await expandPermissionMenu(userRow);

    assert
      .dom(permissionOptionSelector("owner"))
      .doesNotExist("does not offer Owner during target creation");
  });

  test("allows an owner manager to remove their own owner row", async function (assert) {
    this.currentUser = logIn(this.owner);
    const currentUserId = this.currentUser.id;
    const coOwnerId = currentUserId + 1;
    const state = controlledState([
      {
        type: "user",
        id: currentUserId,
        permission: "owner",
        username: this.currentUser.username,
        display_name: this.currentUser.username,
      },
      {
        type: "user",
        id: coOwnerId,
        permission: "owner",
        username: "co-owner",
        display_name: "co-owner",
      },
    ]);
    const currentOwnerRow = `.d-access-control__row[data-row-type="user"][data-row-id="${currentUserId}"]`;

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @canManageOwners={{true}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    await selectPermission("remove", currentOwnerRow);

    assert.deepEqual(
      state.onChangeCalls[0].map((entry) => entry.id),
      [coOwnerId],
      "removes the current user while retaining the co-owner"
    );
  });

  test("does not offer owner as a permission for ordinary rows", async function (assert) {
    const state = controlledState([
      {
        type: "group",
        id: 999,
        permission: "view",
        display_name: "Some Group",
      },
    ]);
    const transformPermissionOptions = (permissions) => [
      ...permissions,
      {
        id: "owner",
        level: 3,
        name: "Owner",
      },
    ];

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
          @transformPermissionOptions={{transformPermissionOptions}}
        />
      </template>
    );

    await expandPermissionMenu();

    assert
      .dom(permissionOptionSelector("owner"))
      .doesNotExist("keeps the reserved owner permission out of the menu");
  });

  test("sorts rows by mandatory and owner status, then type and name", async function (assert) {
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
      {
        type: "user",
        id: 3,
        permission: "owner",
        display_name: "Owner User",
      },
    ]);

    await render(
      <template>
        <DAccessControl
          @acl={{state.acl}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert.deepEqual(
      rowNames(),
      [
        "Alpha Group",
        "Zoe User",
        "Owner User",
        "Apple Group",
        "Beta Group",
        "Aaron User",
      ],
      "sorts mandatory rows by name, then owners, groups, and users"
    );
    assert.deepEqual(
      findAll(".d-access-control__row").map((row) => row.dataset.rowType),
      ["group", "user", "user", "group", "group", "user"],
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
          @acl={{state.acl}}
          @aclTarget={{aclTarget}}
          @groups={{GROUPS}}
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
      .dom(".d-access-control__item-name")
      .includesText("Team A", "renders the mandatory group's name");

    assert
      .dom(".d-access-control__permission")
      .hasText(
        i18n("access_control.manage.access_permission_editor"),
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
          @acl={{state.acl}}
          @aclTarget={{aclTarget}}
          @groups={{GROUPS}}
          @onChange={{state.onChange}}
        />
      </template>
    );

    assert
      .dom(".d-access-control__row")
      .exists({ count: 1 }, "does not render a duplicate group row");

    assert
      .dom(".d-access-control__permission")
      .hasText(
        i18n("access_control.manage.access_permission_editor"),
        "uses the mandatory permission"
      );
  });
});

module("Integration | Component | DAccessControlField", function (hooks) {
  setupRenderingTest(hooks);

  test("binds a named field and updates FormKit without an onChange callback", async function (assert) {
    this.currentUser = logIn(this.owner);
    this.site.groups = GROUPS;
    this.data = {
      permissions: [
        {
          type: "user",
          id: this.currentUser.id,
          permission: "owner",
          username: this.currentUser.username,
          display_name: this.currentUser.username,
        },
      ],
    };
    this.onSubmit = sinon.spy();
    pretender.post("/access-control/evaluate.json", (request) => {
      const payload = JSON.parse(request.requestBody);
      assert.strictEqual(
        payload.target_type,
        aclTarget.type,
        "evaluates the target class"
      );
      assert.strictEqual(
        payload.new_acl.find((entry) => entry.type === "group").id,
        42,
        "evaluates the named field value"
      );
      return response({});
    });

    await render(
      <template>
        <Form @data={{this.data}} @onSubmit={{this.onSubmit}} as |form|>
          <DAccessControlField
            @aclTarget={{aclTarget}}
            @form={{form}}
            @name="permissions"
            @title="Permissions"
          />
          <form.Submit />
        </Form>
      </template>
    );

    const chooser = selectKit(".d-access-control__chooser");
    await chooser.expand();
    await chooser.selectRowByValue("group:42");
    await formKit().submit();

    const data = this.onSubmit.firstCall.args[0];
    assert.strictEqual(
      data.permissions.find((entry) => entry.type === "group").permission,
      "edit",
      "submits the updated permissions"
    );
    assert.false(
      Object.hasOwn(data, "acl"),
      "does not create the default acl field"
    );
  });

  test("reports confirmed access loss and allows submission", async function (assert) {
    this.currentUser = logIn(this.owner);
    const dialog = getOwner(this).lookup("service:dialog");
    sinon.stub(dialog, "confirm").resolves(true);

    pretender.post("/access-control/evaluate.json", () =>
      response(422, {
        errors: ["You will lose permission to manage this target."],
        extras: {
          current_user_will_lose_permission: true,
          loss_warning_permissions: ["manage"],
        },
      })
    );

    this.data = {
      acl: [
        {
          type: "user",
          id: this.currentUser.id,
          permission: "owner",
          username: this.currentUser.username,
          display_name: this.currentUser.username,
        },
      ],
    };
    this.onChange = sinon.spy();
    this.onSubmit = sinon.spy();
    this.onAccessLossConfirmed = sinon.spy();

    await render(
      <template>
        <Form @data={{this.data}} @onSubmit={{this.onSubmit}} as |form|>
          <DAccessControlField
            @aclTarget={{aclTarget}}
            @form={{form}}
            @onAccessLossConfirmed={{this.onAccessLossConfirmed}}
            @onChange={{this.onChange}}
            @title="Access"
          />
          <form.Submit />
        </Form>
      </template>
    );

    await formKit().submit();

    assert.true(this.onSubmit.calledOnce, "the form submits");
    assert.deepEqual(
      this.onAccessLossConfirmed.firstCall.args,
      [{ permissions: ["manage"] }],
      "the confirmed warning permissions are reported"
    );
  });

  test("prevents an existing target from submitting without an owner", async function (assert) {
    this.data = {
      acl: [
        {
          type: "user",
          id: 7,
          permission: "owner",
          username: "martin",
          display_name: "martin",
        },
      ],
    };
    this.onSubmit = sinon.spy();
    pretender.post("/access-control/evaluate.json", () => response({}));

    await render(
      <template>
        <Form @data={{this.data}} @onSubmit={{this.onSubmit}} as |form|>
          <DAccessControlField
            @aclTarget={{aclTarget}}
            @canManageOwners={{true}}
            @form={{form}}
            @title="Access"
          />
          <form.Submit />
        </Form>
      </template>
    );

    await selectPermission(
      "remove",
      '.d-access-control__row[data-row-type="user"][data-row-id="7"]'
    );
    await formKit().submit();

    assert
      .form()
      .field("acl")
      .hasError(
        i18n("access_control.manage.owner_required", {
          typeName: aclTarget.name,
        }),
        "explains that the final owner cannot be removed"
      );
    assert.false(this.onSubmit.called, "does not submit the ownerless ACL");
  });
});
