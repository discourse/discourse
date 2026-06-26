import Service from "@ember/service";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorRichTextField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector-rich-text-field";

// Minimal FormKit FieldData stand-in: the control reads `.value` / `.name`
// and writes through `.set`, recording each commit for assertions.
function makeCustom(value, name = "text") {
  return {
    name,
    value,
    commits: [],
    set(next) {
      this.value = next;
      this.commits.push(next);
    },
  };
}

// Stub wireframe service: the inline-edit identity the read-only guard reads,
// plus the live-value lookup (`selectedBlockData` + `structuralVersion`) the
// editor seeds from. `selectedBlockData` is null by default, so the editor
// falls back to the FormKit draft (`@custom.value`).
class StubWireframeService extends Service {
  // The query layer moved to a leaf the editor exposes as layoutQuery; returning
  selectedBlockKey = null;

  selectedBlockData = null;

  structuralVersion = 0;

  inlineEdit = { isActive: false, argName: null, blockKey: null };

  // this makes wireframe.layoutQuery.<query> resolve to the stubbed methods below.
  get layoutQuery() {
    return this;
  }
}

module("Integration | Wireframe | InspectorRichTextField", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:wireframe");
    this.owner.register("service:wireframe", StubWireframeService);
  });

  test("heading schema mounts the editor with a formatting toolbar", async function (assert) {
    const custom = makeCustom("Hello");
    await render(
      <template>
        <InspectorRichTextField @custom={{custom}} @schema="heading" />
      </template>
    );

    assert
      .dom(".wireframe-inspector-rich-text__toolbar")
      .exists("the bold / italic / link toolbar renders");
    assert
      .dom(".wireframe-inspector-rich-text__btn")
      .exists({ count: 3 }, "three formatting buttons");
    assert
      .dom(".wireframe-inspector-rich-text__editor .wf-inline-editor")
      .exists("the ProseMirror editor mounted into the control");
  });

  test("plain schema mounts the editor without a toolbar", async function (assert) {
    const custom = makeCustom("Label");
    await render(
      <template>
        <InspectorRichTextField @custom={{custom}} @schema="plain" />
      </template>
    );

    assert
      .dom(".wireframe-inspector-rich-text__toolbar")
      .doesNotExist("plain has no marks, so no toolbar");
    assert
      .dom(".wireframe-inspector-rich-text__editor .wf-inline-editor")
      .exists("the editor still mounts");
  });

  test("goes inert (dimmed, formatting kept, buttons disabled) while the canvas edits this target", async function (assert) {
    const stub = this.owner.lookup("service:wireframe");
    stub.selectedBlockKey = "block-1";
    stub.inlineEdit = {
      isActive: true,
      argName: "text",
      blockKey: "block-1",
    };

    const custom = makeCustom({
      type: "doc",
      content: [{ type: "text", text: "Hi", marks: [{ type: "strong" }] }],
    });

    await render(
      <template>
        <InspectorRichTextField @custom={{custom}} @schema="heading" />
      </template>
    );

    // Same editor element, just dimmed — no component swap (no layout shift).
    assert
      .dom(".wireframe-inspector-rich-text__editor.--disabled")
      .exists("the editor box is marked inert");
    // Formatting is preserved because the live editor keeps rendering the doc.
    assert
      .dom(".wireframe-inspector-rich-text__editor .wf-inline-editor strong")
      .hasText(
        "Hi",
        "marks still render (not flattened to plain text/markdown)"
      );
    assert
      .dom(".wireframe-inspector-rich-text__btn:not([disabled])")
      .doesNotExist("every toolbar button is disabled while inert");
  });

  test("seeds from the live block-arg value, not a stale FormKit draft", async function (assert) {
    const stub = this.owner.lookup("service:wireframe");
    stub.selectedBlockKey = "block-1";
    // `text` is a declared block arg whose live value diverged from the draft
    // (e.g. a canvas edit committed it). The editor must show the live value.
    stub.selectedBlockData = {
      metadata: { args: { text: {} } },
      args: { text: "live value" },
    };

    const custom = makeCustom("stale draft");

    await render(
      <template>
        <InspectorRichTextField @custom={{custom}} @schema="heading" />
      </template>
    );

    assert
      .dom(".wireframe-inspector-rich-text__editor .wf-inline-editor")
      .hasText(
        "live value",
        "seeds from the live entry args, not the frozen FormKit draft"
      );
  });

  test("does not commit when nothing changed", async function (assert) {
    const custom = makeCustom("Hello");
    await render(
      <template>
        <InspectorRichTextField @custom={{custom}} @schema="heading" />
      </template>
    );

    // Focus leaves the control entirely (relatedTarget outside the root).
    await triggerEvent(".wireframe-inspector-rich-text", "focusout", {
      relatedTarget: document.body,
    });

    assert.deepEqual(
      custom.commits,
      [],
      "an unchanged edit session writes nothing back (dirty check)"
    );
  });
});
