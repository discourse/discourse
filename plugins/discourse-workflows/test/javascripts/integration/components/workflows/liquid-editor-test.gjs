import { render, triggerEvent, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";
import buildLiquidExtensions from "discourse/plugins/discourse-workflows/admin/lib/workflows/liquid-extensions";

const INPUT_FIELDS = [
  { key: "name", id: "$json.name", type: "string" },
  {
    key: "topic",
    id: "$json.topic",
    type: "object",
    children: [{ key: "title", id: "$json.topic.title", type: "string" }],
  },
];

function liquidExtensions(cmParams) {
  return buildLiquidExtensions(cmParams, { inputFields: INPUT_FIELDS });
}

module("Integration | Component | Workflows | Liquid editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("highlights the template's tags and output", async function (assert) {
    const value = "{% for item in items %}{{ item.name }}{% endfor %}";

    await render(
      <template>
        <VariableInput @extensions={{liquidExtensions}} @value={{value}} />
      </template>
    );
    await waitFor(".cm-wf-brace");

    assert.dom(".cm-wf-brace").exists("delimiters are highlighted");
    assert
      .dom(".cm-wf-keyword")
      .exists("the tag keyword is highlighted separately from its arguments");
    assert.dom(".cm-wf-property").exists("a dotted property is highlighted");
  });

  test("drops a dragged field as a Liquid output tag", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);

    await render(
      <template>
        <VariableInput
          @extensions={{liquidExtensions}}
          @onSetup={{onSetup}}
          @value=""
        />
      </template>
    );
    await waitFor(".cm-editor");

    await triggerEvent(this.element.querySelector(".cm-editor"), "drop", {
      dataTransfer: {
        getData: (type) =>
          type === WORKFLOW_VARIABLE_MIME
            ? JSON.stringify({ id: "$json.topic.title", type: "string" })
            : "",
      },
    });

    assert.strictEqual(
      view.state.doc.toString(),
      "{{ items[0].topic.title }}",
      "the expression path is rewritten for the Liquid render context"
    );
  });

  test("drops relative to the enclosing loop variable", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const value = "{% for row in items %}\n";

    await render(
      <template>
        <VariableInput
          @extensions={{liquidExtensions}}
          @onSetup={{onSetup}}
          @value={{value}}
        />
      </template>
    );
    await waitFor(".cm-editor");

    // Drop coordinates don't resolve in a rendering test, so the drop lands
    // at the end of the document, inside the still-open loop.
    await triggerEvent(this.element.querySelector(".cm-editor"), "drop", {
      dataTransfer: {
        getData: (type) =>
          type === WORKFLOW_VARIABLE_MIME
            ? JSON.stringify({ id: "$json.name", type: "string" })
            : "",
      },
    });

    assert.true(
      view.state.doc.toString().includes("{{ row.name }}"),
      "the path is written against the loop variable in scope"
    );
  });

  test("ignores a field the render context cannot reach", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);

    await render(
      <template>
        <VariableInput
          @extensions={{liquidExtensions}}
          @onSetup={{onSetup}}
          @value=""
        />
      </template>
    );
    await waitFor(".cm-editor");

    await triggerEvent(this.element.querySelector(".cm-editor"), "drop", {
      dataTransfer: {
        getData: (type) =>
          type === WORKFLOW_VARIABLE_MIME
            ? JSON.stringify({
                id: '$("Other").item.json.id',
                type: "string",
              })
            : "",
      },
    });

    assert.strictEqual(
      view.state.doc.toString(),
      "",
      "another node's output is not inserted as an unresolvable path"
    );
  });
});
