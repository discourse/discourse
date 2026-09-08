import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import Field from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field";

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
  }
);
