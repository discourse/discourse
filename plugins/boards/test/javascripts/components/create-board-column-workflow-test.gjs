import { hash } from "@ember/helper";
import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | CreateBoardColumnWorkflow", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_discourse_workflows = true;
    this.fieldComponent =
      require("discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field").default;
    this.variableMime =
      require("discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context").WORKFLOW_VARIABLE_MIME;
    this.data = {};
    this.onSubmit = sinon.spy();
    this.boardSchema = {
      type: "integer",
      required: true,
      type_options: { load_options_method: "boards" },
      ui: { control: "combo_box" },
      control_options: {
        filterable: true,
        value_property: "id",
        name_property: "name",
      },
    };
    this.definition = {
      name: "action:create_board_column",
      metadata: { boards: [{ id: 42, name: "Project board" }] },
    };
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response({ variables: [] })
    );
  });

  test("selects a board ID and accepts a previous node output instead", async function (assert) {
    await render(
      <template>
        <Form @data={{this.data}} @onSubmit={{this.onSubmit}} as |form data|>
          <this.fieldComponent
            @configuration={{data}}
            @fieldName="board_id"
            @form={{form}}
            @label="Board"
            @nodeDefinition={{this.definition}}
            @schema={{this.boardSchema}}
          />
          <form.Submit />
        </Form>
      </template>
    );
    const chooser = selectKit(".combo-box");
    await chooser.expand();
    await chooser.selectRowByValue(42);
    await formKit().submit();
    assert.strictEqual(
      this.onSubmit.firstCall.args[0].board_id,
      42,
      "stores the integer ID"
    );
    await triggerEvent(".workflows-property-engine__control-wrapper", "drop", {
      dataTransfer: {
        types: [this.variableMime],
        getData: () => JSON.stringify({ id: "board_id" }),
      },
    });
    assert
      .dom(".cm-content")
      .exists("switches the board selector to an expression");
    await formKit().submit();
    assert.strictEqual(
      this.onSubmit.lastCall.args[0].board_id,
      "={{ $json.board_id }}",
      "keeps the earlier node's board ID expression"
    );
  });

  test("renders the color picker and preserves dropped expressions", async function (assert) {
    await render(
      <template>
        <Form @data={{this.data}} @onSubmit={{this.onSubmit}} as |form data|>
          <this.fieldComponent
            @configuration={{data}}
            @fieldName="color"
            @form={{form}}
            @label="Color"
            @schema={{hash type="string" ui=(hash control="color")}}
          />
          <form.Submit />
        </Form>
      </template>
    );
    assert.dom('input[type="color"]').exists("uses the FormKit color picker");
    await fillIn('input[type="text"]', "ff8800");
    await formKit().submit();
    assert.strictEqual(
      this.onSubmit.firstCall.args[0].color,
      "ff8800",
      "saves the selected color"
    );
    await triggerEvent('input[type="text"]', "drop", {
      clientX: 0,
      clientY: 0,
      dataTransfer: {
        types: [this.variableMime],
        getData: () => JSON.stringify({ id: "color" }),
      },
    });
    assert.dom(".cm-content").exists("accepts dynamic colors");
  });
});
