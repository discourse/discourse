import { tracked } from "@glimmer/tracking";
import {
  find,
  render,
  settled,
  triggerEvent,
  waitFor,
} from "@ember/test-helpers";
import { startCompletion } from "@codemirror/autocomplete";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import LiquidControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/liquid-control";
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

  test("preserves field accessibility, resizing, and disabled state", async function (assert) {
    const field = new (class {
      @tracked disabled = true;
      @tracked error = "Invalid template";
      id = "template-input";
      name = "template";
      describedBy = "template-help";
      value = "original";

      set() {
        assert.step("changed");
      }
    })();

    await render(<template><LiquidControl @field={{field}} /></template>);
    await waitFor(".cm-editor");
    assert
      .dom(".cm-content")
      .hasAttribute("id", field.id, "the label targets the editable element");
    assert
      .dom(".cm-content")
      .hasAttribute(
        "aria-describedby",
        field.describedBy,
        "help text is associated"
      );
    assert
      .dom(".cm-content")
      .hasAttribute("aria-invalid", "true", "validation state is exposed");
    assert
      .dom(".cm-content")
      .hasAttribute(
        "contenteditable",
        "false",
        "disabled fields cannot be edited"
      );
    assert
      .dom(".code-editor .grippie")
      .exists("the resize handle remains available");

    await triggerEvent(".cm-editor", "drop", {
      dataTransfer: {
        getData: () => JSON.stringify({ id: "$json.name" }),
      },
    });
    assert
      .dom(".cm-content")
      .hasText("original", "drops cannot change a disabled field");
    assert.verifySteps([], "no field update is emitted");

    field.disabled = false;
    field.error = null;
    await settled();
    assert
      .dom(".cm-content")
      .hasAttribute("contenteditable", "true", "editing can be enabled");
    assert
      .dom(".cm-content")
      .doesNotHaveAttribute("aria-invalid", "validation state can clear");
  });

  test("completes a branch at its original input port after a connection is removed", async function (assert) {
    const node = { clientId: "template", name: "Template" };
    const session = {
      graphNodes: [
        { clientId: "first", name: "First" },
        { clientId: "third", name: "Third" },
        node,
      ],
      graphConnections: [
        {
          sourceClientId: "first",
          targetClientId: "template",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "third",
          targetClientId: "template",
          targetInputIndex: 2,
        },
      ],
      pinnedItemsForNode(name) {
        return name === "Third"
          ? [{ json: { email: "alice@example.com" } }]
          : [{ json: { name: "Alice" } }];
      },
    };
    const field = { value: "{{ inputs[2][0].", set() {} };

    await render(
      <template>
        <LiquidControl @field={{field}} @node={{node}} @session={{session}} />
      </template>
    );
    await waitFor(".cm-editor");

    const view = find(".codemirror-editor").codemirrorView;
    view.dispatch({ selection: { anchor: view.state.doc.length } });
    startCompletion(view);
    await waitFor(".cm-completionLabel");

    assert
      .dom(".cm-tooltip-autocomplete")
      .includesText("email", "the third input retains its field completions");
    assert
      .dom(".cm-tooltip-autocomplete")
      .doesNotIncludeText("name", "the first input's fields stay separate");
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
