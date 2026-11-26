import { tracked } from "@glimmer/tracking";
import {
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import CodeEditor from "discourse/components/code-editor";
import { registerCodeEditorLanguage } from "discourse/lib/code-editor-languages";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import LiquidControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/liquid-control";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

async function renderEditor(field, { node, session } = {}) {
  await render(
    <template>
      <LiquidControl @field={{field}} @node={{node}} @session={{session}} />
    </template>
  );
  await waitFor(".cm-editor");
  return find(".codemirror-editor").codemirrorView;
}

async function dropVariable(view, id, pos = view.state.doc.length) {
  const coords = view.coordsAtPos(pos);
  await triggerEvent(".cm-editor", "drop", {
    clientX: coords?.right,
    clientY: coords?.top,
    dataTransfer: {
      getData: (mime) =>
        mime === WORKFLOW_VARIABLE_MIME
          ? JSON.stringify({ id, type: "string" })
          : "",
    },
  });
}

// Each keystroke goes through the editor's input handlers, as typing does; a
// read-only editor takes nothing.
function type(view, text) {
  for (const char of text) {
    const { from, to } = view.state.selection.main;
    const handled = view.state
      .facet(view.constructor.inputHandler)
      .some((handler) => handler(view, from, to, char, () => null));
    if (!handled && !view.state.readOnly) {
      view.dispatch(view.state.replaceSelection(char));
    }
  }
}

module("Integration | Component | Workflows | LiquidEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("keeps the field editable when the grammar fails to load", async function (assert) {
    const failure = new Error("Liquid chunk unavailable");
    registerCodeEditorLanguage("liquid", () => Promise.reject(failure));
    const consoleError = sinon.stub(console, "error");
    const field = { value: "Draft", set: sinon.spy() };
    const view = await renderEditor(field);
    await waitUntil(() => consoleError.called);

    assert.dom(".cm-content").hasText("Draft", "preserves the template");
    view.dispatch({ selection: { anchor: view.state.doc.length } });
    type(view, "!");
    await settled();
    assert.true(
      field.set.calledWith("Draft!"),
      "still sends edits to the form"
    );
  });

  for (const source of ["pinned", "execution"]) {
    test(`refreshes ${source} fields without a schema change`, async function (assert) {
      const node = { clientId: "template", name: "Template" };
      const session = {
        graphNodes: [{ clientId: "first", name: "First" }, node],
        graphConnections: [
          {
            sourceClientId: "first",
            targetClientId: "template",
            targetInputIndex: 0,
          },
        ],
        outputSchemas: {},
        pinnedItemsForNode() {
          return this.pinnedItems;
        },
      };
      function setFields(json) {
        const items = [{ json }];
        if (source === "pinned") {
          session.pinnedItems = items;
        } else {
          session.lastExecutionRunData = {
            First: [
              {
                status: "success",
                outputs: [{ index: 0, items, item_count: 1 }],
              },
            ],
          };
        }
      }
      setFields({ old_field: "old" });
      const view = await renderEditor(
        { value: "{{ items.first.", set() {} },
        { node, session }
      );
      view.dispatch({ selection: { anchor: view.state.doc.length } });
      view.focus();
      await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
      await waitFor(".cm-completionLabel");
      assert
        .dom(".cm-tooltip-autocomplete")
        .includesText("old_field", "uses the initial data");

      setFields({ new_field: "new" });
      await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
      await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
      await waitFor(".cm-completionLabel");
      assert
        .dom(".cm-tooltip-autocomplete")
        .includesText("new_field", "reads the replacement data");
      assert
        .dom(".cm-tooltip-autocomplete")
        .doesNotIncludeText("old_field", "drops stale fields");
    });
  }

  test("refreshes completions and dropped paths after a connection moves", async function (assert) {
    const node = { clientId: "template", name: "Template" };
    const primary = {
      sourceClientId: "first",
      targetClientId: "template",
      targetInputIndex: 0,
    };
    const session = {
      graphNodes: [
        { clientId: "first", name: "First" },
        { clientId: "second", name: "Second" },
        node,
      ],
      graphConnections: [
        primary,
        {
          sourceClientId: "second",
          targetClientId: "template",
          targetInputIndex: 1,
        },
      ],
      outputSchemas: {},
      pinnedItemsForNode(name) {
        return [
          {
            json:
              name === "Second"
                ? { email: "alice@example.com" }
                : { name: "Alice" },
          },
        ];
      },
    };
    const view = await renderEditor(
      { value: "{{ inputs[1].first.", set() {} },
      { node, session }
    );
    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .includesText("email", "starts at input one");
    await triggerKeyEvent(view.contentDOM, "keydown", "Escape");

    session.graphConnections = [
      primary,
      {
        sourceClientId: "second",
        targetClientId: "template",
        targetInputIndex: 2,
      },
    ];
    const text = "{{ inputs[2].first.";
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: text },
      selection: { anchor: text.length },
    });
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .includesText("email", "moves the completion scope to input two");
    await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "" },
    });
    await dropVariable(view, '$("Second").all(0)[$itemIndex].json.email');
    assert.strictEqual(
      view.state.doc.toString(),
      "{{ inputs[2][0].email }}",
      "drops against the current port"
    );
  });

  test("shares Liquid with an HTML editor without sharing its context or handlers", async function (assert) {
    const field = { value: "<main>{{ items }}</main>", set() {} };
    const htmlTemplate = "<main>{{ blog_title }}</main>";
    const htmlOptions = {
      base: "html",
      scope: { blog_title: "Example blog" },
      tags: ["if"],
      filters: ["upcase"],
    };
    await render(
      <template>
        <LiquidControl @field={{field}} />
        <CodeEditor
          class="html-liquid-editor"
          @language="liquid"
          @languageOptions={{htmlOptions}}
          @value={{htmlTemplate}}
        />
      </template>
    );
    await waitFor(".html-liquid-editor .cm-hl-tag");
    await waitFor(".workflows-liquid-control .cm-hl-name");
    assert
      .dom(".workflows-liquid-control .cm-hl-tag")
      .doesNotExist(
        "workflow text does not acquire HTML parsing from the other editor"
      );

    const workflow = find(
      ".workflows-liquid-control .codemirror-editor"
    ).codemirrorView;
    const html = find(".html-liquid-editor .codemirror-editor").codemirrorView;
    for (const [view, present, absent] of [
      [workflow, "items", "blog_title"],
      [html, "blog_title", "items"],
    ]) {
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: "{{ " },
        selection: { anchor: 3 },
      });
      view.focus();
      await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
      await waitUntil(() => view.dom.querySelector(".cm-completionLabel"));
      assert
        .dom(".cm-tooltip-autocomplete", view.dom)
        .includesText(present, "uses its own scope");
      assert
        .dom(".cm-tooltip-autocomplete", view.dom)
        .doesNotIncludeText(absent, "does not leak the other scope");
      await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: "" },
        selection: { anchor: 0 },
      });
      type(view, "{{");
      assert.strictEqual(
        view.state.doc.toString(),
        "{{  }}",
        "only one delimiter handler runs"
      );
      await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
    }
  });

  test("wires the field's accessibility and validation state", async function (assert) {
    const field = new (class {
      @tracked error = "Invalid template";
      id = "template-input";
      name = "template";
      describedBy = "template-help";
      value = "original";

      set() {}
    })();

    await renderEditor(field);

    assert.dom(".cm-content").hasAttribute("id", field.id);
    assert
      .dom(".cm-content")
      .hasAttribute("aria-describedby", field.describedBy);
    assert.dom(".cm-content").hasAttribute("aria-invalid", "true");
    assert.dom(".code-editor .grippie").exists("resizable");

    field.error = null;
    await settled();
    assert.dom(".cm-content").doesNotHaveAttribute("aria-invalid");
  });

  test("ignores typing and drops on a disabled template", async function (assert) {
    const field = {
      value: "{",
      disabled: true,
      set() {
        assert.step("changed");
      },
    };
    const view = await renderEditor(field);

    assert.true(view.state.readOnly);

    type(view, "{");
    await dropVariable(view, "$json.name");

    assert.strictEqual(view.state.doc.toString(), "{");
    assert.verifySteps([]);
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
    const view = await renderEditor(
      { value: "{{ inputs[2][0].", set() {} },
      { node, session }
    );

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");

    assert.dom(".cm-tooltip-autocomplete").includesText("email");
    assert.dom(".cm-tooltip-autocomplete").doesNotIncludeText("name");
  });

  test("offers the tags the template renders and recommends its items", async function (assert) {
    const view = await renderEditor({ value: "{% en", set() {} });

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");

    assert.dom(".cm-tooltip-autocomplete").includesText("endfor");
    assert
      .dom(".cm-tooltip-autocomplete")
      .doesNotIncludeText("render", "the server has no partials to render");

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "{{ it" },
      selection: { anchor: 5 },
    });
    await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor("completion-section");

    assert.dom("completion-section").hasText("Recommended");
  });

  test("completes the fields of output schemas that load after it opens", async function (assert) {
    const node = { clientId: "template", name: "Template" };
    const session = {
      graphNodes: [{ clientId: "first", name: "First" }, node],
      graphConnections: [
        {
          sourceClientId: "first",
          targetClientId: "template",
          targetInputIndex: 0,
        },
      ],
      outputSchemas: {},
      pinnedItemsForNode() {},
    };
    const view = await renderEditor(
      { value: "{{ items.first.", set() {} },
      { node, session }
    );

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .doesNotIncludeText("email", "before the schemas load");

    session.outputSchemas = {
      first: [{ type: "object", properties: { email: { type: "string" } } }],
    };
    await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .includesText("email", "once they have");
  });

  test("completes from the scope of the run mode the form has set", async function (assert) {
    const node = {
      clientId: "template",
      name: "Template",
      type: {
        identifier: "action:template",
        capabilities: {
          run_scope: {
            parameter: "mode",
            values: { each: "per_item", once: "all_items" },
          },
        },
      },
    };
    const configuration = { mode: "once" };
    const field = { value: "{{ item_", set() {} };

    await render(
      <template>
        <LiquidControl
          @configuration={{configuration}}
          @field={{field}}
          @node={{node}}
        />
      </template>
    );
    await waitFor(".cm-editor");
    const view = find(".codemirror-editor").codemirrorView;
    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();

    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .doesNotIncludeText("item_index", "once for all items");

    configuration.mode = "each";
    await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");
    assert
      .dom(".cm-tooltip-autocomplete")
      .includesText("item_index", "once for each item");
  });

  test("lists what a template sets with the other variables", async function (assert) {
    const view = await renderEditor({ value: "", set() {} });
    const sectionOf = (label) => {
      let element = [
        ...document.querySelectorAll(".cm-tooltip-autocomplete li"),
      ].find(
        (item) =>
          item.querySelector(".cm-completionLabel").textContent === label
      );
      while (element && element.tagName !== "COMPLETION-SECTION") {
        element = element.previousElementSibling;
      }
      return element?.textContent;
    };
    const completeAt = async (doc) => {
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: doc },
        selection: { anchor: doc.length },
      });
      view.focus();
      await triggerKeyEvent(view.contentDOM, "keydown", "Escape");
      await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
      await waitFor(".cm-completionLabel");
    };

    await completeAt("{% for row in items %}{{ ");
    assert.strictEqual(sectionOf("row"), "Recommended");
    assert
      .dom(".cm-completionLabel")
      .hasText("row", "a loop variable comes before its collection");

    await completeAt("{% assign name = workflow.name %}{{ ");
    assert.strictEqual(
      sectionOf("name"),
      "Metadata",
      "an assigned property is a variable"
    );
  });

  test("typing an opening delimiter closes it once", async function (assert) {
    const view = await renderEditor({ value: "", set() {} });
    await waitUntil(() => view.state.languageDataAt("closeBrackets", 0).length);

    type(view, "{{");
    assert.strictEqual(view.state.doc.toString(), "{{  }}", "output tag");

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "" },
    });
    type(view, "{%");
    assert.strictEqual(view.state.doc.toString(), "{%  %}", "logic tag");

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "}}" },
      selection: { anchor: 0 },
    });
    type(view, "{{");
    assert.strictEqual(
      view.state.doc.toString(),
      "{{  }}",
      "an existing closer is reused"
    );
  });

  test("highlights the template's tags and output", async function (assert) {
    await renderEditor({
      value: "{% for item in items %}{{ item.name | upcase }}{% endfor %}",
      set() {},
    });
    await waitFor(".cm-hl-bracket");

    assert.dom(".cm-hl-control").exists({ count: 2 }, "for and endfor");
    assert.dom(".cm-hl-property").hasText("name");
    assert.dom(".cm-hl-function").hasText("upcase");
  });

  for (const statementBlock of [false, true]) {
    test(`maps drops using ${statementBlock ? "statement" : "ordinary"} loop syntax`, async function (assert) {
      const view = await renderEditor({ value: "", set() {} });
      const cases = [
        { loops: ["for entry in items"], path: "entry.name" },
        { loops: ["for entry in inputs[0]"], path: "entry.name" },
        { loops: ["for entry in items offset: 1"], path: "entry.name" },
        {
          loops: ["for entry in items", "for entry in entry.tags"],
          path: "items[forloop.parentloop.index0].name",
        },
        {
          loops: ["for entry in items reversed limit: 2"],
          id: "$itemIndex",
          path: "forloop.rindex0",
        },
        {
          loops: ["for entry in items offset: 1"],
          id: "$itemIndex",
          path: null,
        },
        {
          loops: ["for entry in items offset: 1", "for entry in entry.tags"],
          path: null,
        },
        { loops: ["for entry in selected"], path: null },
      ];
      for (const { loops, id = "$json.name", path } of cases) {
        const marked = statementBlock
          ? `{% liquid\n${loops.join("\n")}\necho ◊\n${loops.map(() => "endfor").join("\n")}\n%}`
          : `${loops.map((loop) => `{% ${loop} %}`).join("")}{{ ◊ }}${loops.map(() => "{% endfor %}").join("")}`;
        const pos = marked.indexOf("◊");
        const doc = marked.replace("◊", "");
        view.dispatch({
          changes: { from: 0, to: view.state.doc.length, insert: doc },
        });
        await dropVariable(view, id, pos);
        assert.strictEqual(
          view.state.doc.toString(),
          marked.replace("◊", path ?? ""),
          `${loops.join(" / ")}: ${id}`
        );
      }
    });
  }

  test("handles trimmed, unfinished and closed statement blocks", async function (assert) {
    const view = await renderEditor({ value: "", set() {} });
    for (const [marked, insert] of [
      ["{%- liquid\nfor entry in items\necho ◊\nendfor\n-%}", "entry.name"],
      ["{% liquid\nfor entry in items\necho ◊", "entry.name"],
      [
        "{% liquid\nfor entry in items\nassign value = ◊\nendfor\n%}",
        "entry.name",
      ],
      [
        "{% liquid\nfor entry in items\necho entry.name\nendfor\n%}◊",
        "{{ items[0].name }}",
      ],
    ]) {
      const pos = marked.indexOf("◊");
      view.dispatch({
        changes: {
          from: 0,
          to: view.state.doc.length,
          insert: marked.replace("◊", ""),
        },
      });
      await dropVariable(view, "$json.name", pos);
      assert.strictEqual(
        view.state.doc.toString(),
        marked.replace("◊", insert),
        marked
      );
    }
  });

  test("declines ambiguous scopes and invalid insertion positions", async function (assert) {
    const view = await renderEditor({ value: "", set() {} });
    for (const marked of [
      "{% assign selected = items %}{% for entry in selected %}{{ ◊ }}{% endfor %}",
      "{% assign items = other %}{{ ◊ }}",
      "{% for inputs in items %}{{ ◊ }}{% endfor %}",
      "{% for item in inputs[2] %}{{ ◊ }}{% endfor %}",
      "{% for entry in items.first %}{{ ◊ }}{% endfor %}",
      "{% for entry in items %}{% assign entry = other %}{{ ◊ }}{% endfor %}",
      "{% for entry in items %}{% capture entry %}plain{% endcapture %}{{ ◊ }}{% endfor %}",
      "{% for entry in items %}{% else %}◊{% endfor %}",
      "{% tablerow entry in items %}◊{% endtablerow %}",
      "{% liquid\nfor entry in items\n# ◊\nendfor\n%}",
      '{% liquid\nfor entry in items\necho "◊"\nendfor\n%}',
      "{% liquid\nfor entry in items\nassign ◊ = 1\nendfor\n%}",
      "{% liquid\nfor ◊ in items\necho 1\nendfor\n%}",
      "{% comment %}{% for entry in items %}◊{% endcomment %}",
      "{% raw %}{% for entry in items %}◊{% endraw %}",
      '{{ "◊" }}',
      "{{ existing◊ }}",
    ]) {
      const pos = marked.indexOf("◊");
      const doc = marked.replace("◊", "");
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: doc },
      });
      await dropVariable(view, "$json.name", pos);
      assert.strictEqual(view.state.doc.toString(), doc, marked);
    }
  });

  test("maps secondary inputs through statement loop indexes", async function (assert) {
    const node = { clientId: "template", name: "Template" };
    const session = {
      graphNodes: [
        { clientId: "first", name: "First" },
        { clientId: "second", name: "Second" },
        node,
      ],
      graphConnections: [
        {
          sourceClientId: "first",
          targetClientId: "template",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "second",
          targetClientId: "template",
          targetInputIndex: 2,
        },
      ],
      pinnedItemsForNode() {},
    };
    const view = await renderEditor({ value: "", set() {} }, { node, session });
    for (const [loops, path] of [
      [
        "for entry in items\nfor tag in entry.tags",
        "inputs[2][forloop.parentloop.index0].email",
      ],
      ["for entry in items reversed", "inputs[2][forloop.rindex0].email"],
      ["for entry in items offset: 1", null],
      ["for entry in inputs[2]", "entry.email"],
    ]) {
      const marked = `{% liquid\n${loops}\necho ◊`;
      const pos = marked.indexOf("◊");
      view.dispatch({
        changes: {
          from: 0,
          to: view.state.doc.length,
          insert: marked.replace("◊", ""),
        },
      });
      await dropVariable(
        view,
        '$("Second").all(0)[$itemIndex].json.email',
        pos
      );
      assert.strictEqual(
        view.state.doc.toString(),
        marked.replace("◊", path ?? ""),
        loops
      );
    }
  });

  test("drops a dragged field as a path the template can render", async function (assert) {
    const view = await renderEditor({
      value: "{% for row in items %}\n",
      set() {},
    });

    await dropVariable(view, "$json.name");

    assert.strictEqual(
      view.state.doc.toString(),
      "{% for row in items %}\n{{ row.name }}"
    );
  });

  test("drops a bare path inside an open output tag", async function (assert) {
    const view = await renderEditor({ value: "{{ ", set() {} });

    await dropVariable(view, "$json.topic.title");

    assert.strictEqual(view.state.doc.toString(), "{{ items[0].topic.title");
  });
});
