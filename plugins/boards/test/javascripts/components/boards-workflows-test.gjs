import { hash } from "@ember/helper";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import initializer from "discourse/plugins/boards/discourse/initializers/boards-workflows";

module("Integration | Component | BoardsWorkflows", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_discourse_workflows = true;
    this.siteSettings.boards_manage_board_allowed_groups = "1|2";
    initializer.initialize(this.owner, this.owner);
    this.fieldComponent =
      require("discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field").default;
    this.createNode =
      require("discourse/plugins/discourse-workflows/admin/components/workflows/editor/node-factory").createNode;
    this.node = this.createNode("action:create_board", []);
    this.onSubmit = sinon.spy();
    this.schema = {
      type: "object",
      required: true,

      ui: { control: "access_control", expression: false },
      control_options: {
        acl_target_type: "Boards::Board",
        acl_target_key: "Boards::Board",
        required_permissions: ["manage"],
        permissions: ["view", "edit", "manage"],
      },
    };
    this.site.access_control = {
      mandatory_acl: {
        "Boards::Board": [{ type: "group", id: 1, permission: "manage" }],
      },
      banned_acl: {
        "Boards::Board": [
          {
            type: "group",
            id: AUTO_GROUPS.logged_in_users.id,
            permission: "edit",
          },
        ],
      },
    };
    pretender.post("/access-control/evaluate.json", () => response({}));
  });

  test("creates defaults from manager groups without overwriting an explicit ACL", function (assert) {
    assert.deepEqual(
      this.node.configuration.acl.map(({ id, permission }) => ({
        id,
        permission,
      })),
      [
        { id: 1, permission: "manage" },
        { id: 2, permission: "manage" },
        { id: AUTO_GROUPS.logged_in_users.id, permission: "view" },
      ],
      "new nodes use the board settings defaults"
    );
    this.siteSettings.boards_manage_board_allowed_groups = "1|5";
    const node = this.createNode("action:create_board", []);
    assert.deepEqual(
      node.configuration.acl.map(({ id, permission }) => ({ id, permission })),
      [
        { id: 1, permission: "manage" },
        { id: 5, permission: "manage" },
      ],
      "logged-in managers are not duplicated"
    );
    const explicit = this.createNode("action:create_board", [], null, {
      configOverrides: { acl: [] },
    });
    assert.deepEqual(
      explicit.configuration.acl,
      [],
      "keeps explicitly supplied ACLs"
    );
    assert.false(
      Object.hasOwn(this.createNode("action:example", []).configuration, "acl"),
      "does not add defaults to other nodes"
    );
  });

  test("uses the board permissions and submits changes through FormKit", async function (assert) {
    await render(
      <template>
        <Form
          @data={{this.node.configuration}}
          @onSubmit={{this.onSubmit}}
          as |form data|
        >
          <this.fieldComponent
            @configuration={{data}}
            @fieldName="acl"
            @form={{form}}
            @label="Board access"
            @node={{this.node}}
            @schema={{this.schema}}
          />
          <form.Submit />
        </Form>
      </template>
    );
    assert
      .dom('.d-access-control__row[data-row-id="1"]')
      .hasClass("--mandatory", "locks the mandatory admin permission");
    await click(
      '.d-access-control__row[data-row-id="5"] .d-access-control__permission'
    );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="manage"]')
      .includesText(
        i18n("boards.manage.board_access_permission_manager"),
        "offers board management"
      );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="view"]')
      .includesText(
        i18n("boards.manage.board_access_permission_viewer_description"),
        "uses board-specific descriptions"
      );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="edit"]')
      .doesNotExist("applies the board's banned permissions");
    await click(
      '.d-access-control__permission-option[data-permission-id="manage"]'
    );
    await fillIn(".workflows-access-control__groups input", "[41,42]");
    await click(
      ".workflows-access-control__permission .d-access-control__permission"
    );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="manage"]')
      .includesText(
        i18n("boards.manage.board_access_permission_manager_description"),
        "shows the board manager description for input groups"
      );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="view"]')
      .includesText(
        i18n("boards.manage.board_access_permission_viewer_description"),
        "shares the board viewer description"
      );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="remove"]')
      .doesNotExist("input groups do not offer Remove");
    await click(
      '.d-access-control__permission-option[data-permission-id="manage"]'
    );
    await formKit().submit();
    assert.strictEqual(
      this.onSubmit.firstCall.args[0].acl.permission,
      "manage",
      "saves the shared manager permission"
    );
    assert.deepEqual(
      this.onSubmit.firstCall.args[0].acl.group_ids,
      [41, 42],
      "saves the input groups"
    );
    assert.strictEqual(
      this.onSubmit.firstCall.args[0].acl.entries.find(
        (entry) => entry.id === 5
      ).permission,
      "manage",
      "submits the changed board permission"
    );
  });

  test("requires a manager when there is no mandatory manager or dynamic input", async function (assert) {
    this.site.access_control.mandatory_acl = {};
    this.configuration = {
      acl: [{ type: "group", id: 5, permission: "view" }],
    };
    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onSubmit={{this.onSubmit}}
          as |form data|
        >
          <this.fieldComponent
            @configuration={{data}}
            @fieldName="acl"
            @form={{form}}
            @label="Board access"
            @node={{this.node}}
            @schema={{this.schema}}
          />
          <form.Submit />
        </Form>
      </template>
    );
    await formKit().submit();
    assert.false(this.onSubmit.called, "requires an explicit manager grant");
    assert
      .dom(".form-kit__errors")
      .includesText("manage", "explains the missing permission");
  });

  test("leaves other nodes on the generic ACL renderer", async function (assert) {
    this.configuration = {
      acl: [{ type: "group", id: 5, permission: "view" }],
    };
    this.schema.control_options = { acl_target_type: "Example::Target" };
    await render(
      <template>
        <Form @data={{this.configuration}} as |form data|>
          <this.fieldComponent
            @configuration={{data}}
            @fieldName="acl"
            @form={{form}}
            @label="Access"
            @node={{hash type="action:example"}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );
    await click(
      '.d-access-control__row[data-row-id="5"] .d-access-control__permission'
    );
    assert
      .dom('.d-access-control__permission-option[data-permission-id="manage"]')
      .doesNotExist("does not apply board permissions to other nodes");
  });
});
