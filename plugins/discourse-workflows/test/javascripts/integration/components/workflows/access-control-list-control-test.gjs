import { hash } from "@ember/helper";
import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import Field from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

module(
  "Integration | Component | Workflows | AccessControlListControl",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.site.groups = [
        { id: 41, name: "managers", full_name: "Managers", automatic: false },
        { id: 42, name: "readers", full_name: "Readers", automatic: false },
      ];
      this.site.access_control = {
        mandatory_acl: {
          example: [{ type: "group", id: 41, permission: "edit" }],
        },
        banned_acl: {
          example: [{ type: "group", id: 42, permission: "edit" }],
        },
      };
      this.configuration = { permissions: [] };
      this.onSubmit = sinon.spy();
      this.onSet = sinon.spy((value, { set, name }) => set(name, value));
      this.schema = {
        type: "array",
        required: true,
        no_data_expression: true,
        ui: { control: "access_control" },
        control_options: {
          acl_target_type: "Example::Target",
          acl_target_key: "example",
          required_permissions: ["view"],
        },
      };
      pretender.post("/access-control/evaluate.json", () => response({}));
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response({ variables: [] })
      );
    });

    test("uses the target key for ACL metadata and the class for evaluation", async function (assert) {
      this.configuration.permissions = [
        { type: "group", id: 42, permission: "view" },
      ];
      pretender.post("/access-control/evaluate.json", (request) => {
        assert.strictEqual(
          JSON.parse(request.requestBody).target_type,
          "Example::Target",
          "evaluates the Ruby class"
        );
        return response({});
      });

      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onSubmit={{this.onSubmit}}
            as |form data|
          >
            <Field
              @configuration={{data}}
              @fieldName="permissions"
              @form={{form}}
              @label="Permissions"
              @node={{hash type="action:example"}}
              @onSet={{this.onSet}}
              @schema={{this.schema}}
            />
            <form.Submit />
          </Form>
        </template>
      );

      assert
        .dom('.d-access-control__row[data-row-id="41"]')
        .hasClass("--mandatory", "loads mandatory rows by key");
      await click(
        '.d-access-control__row[data-row-id="42"] .d-access-control__permission'
      );
      assert
        .dom('.d-access-control__permission-option[data-permission-id="edit"]')
        .doesNotExist("filters banned permissions by key");
      await click(
        '.d-access-control__permission-option[data-permission-id="view"]'
      );
      await formKit().submit();
      assert.true(
        this.onSubmit.calledOnce,
        "submits the ACL through the standalone control"
      );
    });

    test("updates the named FormKit field through onSet", async function (assert) {
      this.site.access_control = { mandatory_acl: {}, banned_acl: {} };
      this.schema.control_options.required_permissions = ["edit"];
      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onSubmit={{this.onSubmit}}
            as |form data|
          >
            <Field
              @configuration={{data}}
              @fieldName="permissions"
              @form={{form}}
              @label="Permissions"
              @onSet={{this.onSet}}
              @schema={{this.schema}}
            />
            <form.Submit />
          </Form>
        </template>
      );

      const chooser = selectKit(".d-access-control__chooser");
      await chooser.expand();
      await chooser.selectRowByValue("group:42");
      await formKit().submit();

      assert.true(this.onSet.calledOnce, "uses the field's onSet hook");
      assert.strictEqual(
        this.onSubmit.firstCall.args[0].permissions[0].id,
        42,
        "submits the chosen grantee"
      );
    });

    test("requires the declared permission before submitting", async function (assert) {
      this.configuration.permissions = [
        { type: "group", id: 42, permission: "edit" },
      ];
      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onSubmit={{this.onSubmit}}
            as |form data|
          >
            <Field
              @configuration={{data}}
              @fieldName="permissions"
              @form={{form}}
              @label="Permissions"
              @schema={{this.schema}}
            />
            <form.Submit />
          </Form>
        </template>
      );
      await formKit().submit();
      assert.false(
        this.onSubmit.called,
        "blocks submission without the required permission"
      );
      assert.dom(".form-kit__errors").exists("shows the validation error");
    });

    module("groups from input", function (inputHooks) {
      inputHooks.beforeEach(function () {
        this.schema.type = "object";
        this.schema.no_data_expression = false;
        this.schema.control_options.groups_from_input = true;
        this.site.access_control = { mandatory_acl: {}, banned_acl: {} };
        this.configuration.permissions = [
          { type: "group", id: 41, permission: "view" },
        ];
      });

      async function renderControl(context) {
        await render(
          <template>
            <Form
              @data={{context.configuration}}
              @onSubmit={{context.onSubmit}}
              as |form data|
            >
              <Field
                @configuration={{data}}
                @fieldName="permissions"
                @form={{form}}
                @label="Permissions"
                @onSet={{context.onSet}}
                @schema={{context.schema}}
              />
              <form.Submit />
            </Form>
          </template>
        );
      }

      test("saves a dropped expression and shared permission alongside edited fixed entries", async function (assert) {
        await renderControl(this);
        const transfer = {
          types: [WORKFLOW_VARIABLE_MIME],
          getData: () => JSON.stringify({ id: "group_ids" }),
        };
        await triggerEvent(".workflows-access-control__groups input", "drop", {
          dataTransfer: transfer,
        });
        await fillIn(".workflows-access-control__permission select", "edit");
        const chooser = selectKit(".d-access-control__chooser");
        await chooser.expand();
        await chooser.selectRowByValue("group:42");
        await formKit().submit();

        const saved = this.onSubmit.firstCall.args[0].permissions;
        assert.strictEqual(
          saved.group_ids,
          "={{ $json.group_ids }}",
          "keeps the expression when editing fixed access"
        );
        assert.strictEqual(
          saved.permission,
          "edit",
          "keeps the shared permission"
        );
        assert.deepEqual(
          saved.entries.map(({ id, permission }) => ({ id, permission })),
          [
            { id: 41, permission: "view" },
            { id: 42, permission: "edit" },
          ],
          "saves both fixed entries"
        );
        assert.true(this.onSet.called, "uses the outer FormKit onSet");
        assert
          .dom(".workflows-access-control__groups .cm-content")
          .hasAttribute(
            "aria-label",
            "Groups from input",
            "labels the expression editor"
          );
        assert
          .dom(".workflows-access-control__groups label")
          .hasText(
            "Groups from input (optional)",
            "marks the group input optional"
          );
      });

      test("reopens a saved input and retains it when changing permission", async function (assert) {
        this.configuration.permissions = {
          entries: this.configuration.permissions,
          group_ids: "={{ $json.group_ids }}",
          permission: "edit",
        };
        await renderControl(this);
        assert
          .dom(".workflows-access-control__groups .cm-content")
          .exists("loads the saved expression");
        assert
          .dom(".workflows-access-control__permission select")
          .hasValue("edit", "loads its permission");
        await fillIn(".workflows-access-control__permission select", "view");
        await formKit().submit();
        assert.strictEqual(
          this.onSubmit.firstCall.args[0].permissions.group_ids,
          "={{ $json.group_ids }}",
          "does not replace the expression with preview data"
        );
        assert.strictEqual(
          this.onSubmit.firstCall.args[0].permissions.permission,
          "view",
          "saves the new permission"
        );
      });

      test("defers required permission validation for dynamic groups", async function (assert) {
        this.configuration.permissions = {
          entries: [],
          group_ids: "={{ $json.group_ids }}",
          permission: "view",
        };
        await renderControl(this);
        await formKit().submit();
        assert.true(
          this.onSubmit.calledOnce,
          "allows execution to validate the resolved groups"
        );
      });

      test("clears input groups without removing fixed entries", async function (assert) {
        const entries = this.configuration.permissions;
        this.configuration.permissions = {
          entries,
          group_ids: [42],
          permission: "edit",
        };
        await renderControl(this);
        await fillIn(".workflows-access-control__groups input", "");
        await formKit().submit();
        assert.deepEqual(
          this.onSubmit.firstCall.args[0].permissions,
          { entries, group_ids: "", permission: "edit" },
          "clears only the input groups"
        );
      });

      test("rejects literal values that are not ID arrays", async function (assert) {
        await renderControl(this);
        await fillIn(".workflows-access-control__groups input", "42");
        await formKit().submit();
        assert.false(this.onSubmit.called, "blocks an invalid literal");
        assert
          .dom(".form-kit__errors")
          .includesText("array of group IDs", "explains the expected input");
      });
    });
  }
);
