import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorLayoutForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector-layout-form";

// Minimal stand-in: the layout form reads the selected block's args and a few
// grid helpers off the service, and writes through `updateSelectedArg`. The
// grid helpers return inert values so the form mounts cleanly in every mode.
class StubWireframeService extends Service {
  // The query layer moved to a leaf the editor exposes as layoutQuery; returning
  #args;

  #fieldErrors;

  constructor(owner, args, fieldErrors) {
    super(owner);
    this.#args = args;
    this.#fieldErrors = fieldErrors ?? {};
    this.updateSelectedArgCalls = [];
  }

  // this makes wireframe.layoutQuery.<query> resolve to the stubbed methods below.
  get layoutQuery() {
    return this;
  }

  // The Form seeds its draft from `argsSnapshot`; the canvas-facing `args`
  // mirror it here. `metadata.args` is the (empty) schema the form reads for
  // labels, defaults, and validation rules.
  get selectedBlockData() {
    return {
      key: "layout:test",
      args: this.#args,
      argsSnapshot: this.#args,
      metadata: { args: {} },
    };
  }

  get selectedBlockFieldErrors() {
    return this.#fieldErrors;
  }

  get selectedBlockNonFieldErrors() {
    return [];
  }

  gridSizeFor() {
    return { columns: 2, rows: 2 };
  }

  activeGridTemplate() {
    return null;
  }

  canApplyGridTemplate() {
    return true;
  }

  outOfBoundsSlotsIn() {
    return [];
  }

  updateSelectedArg(name, value) {
    this.updateSelectedArgCalls.push({ name, value });
  }
}

function stubWireframe(owner, args, fieldErrors) {
  const stub = new StubWireframeService(owner, args, fieldErrors);
  owner.unregister("service:wireframe-workspace");
  owner.register("service:wireframe-workspace", stub, { instantiate: false });
  owner.unregister("service:wireframe-selection");
  owner.register("service:wireframe-selection", stub, { instantiate: false });
  // The form writes arg edits through the arg-edit service and reads grid-shape
  // helpers off the grid-template service; point both at the same stub.
  owner.unregister("service:wireframe-arg-edit");
  owner.register("service:wireframe-arg-edit", stub, { instantiate: false });
  owner.unregister("service:wireframe-grid-template");
  owner.register("service:wireframe-grid-template", stub, {
    instantiate: false,
  });
}

module(
  "Integration | Wireframe | InspectorLayoutForm | flex/grid controls",
  function (hooks) {
    setupRenderingTest(hooks);

    test("stack mode: justify-content + reverse, but no wrap control", async function (assert) {
      stubWireframe(this.owner, { mode: "stack" });
      await render(<template><InspectorLayoutForm /></template>);

      assert
        .dom("input[name='wireframe-layout-justify-content']")
        .exists("justify-content renders as a segmented control");
      assert.dom(".d-toggle-switch").exists("reverse toggle renders");
      assert
        .dom("input[name='wireframe-layout-wrap']")
        .doesNotExist("wrap is not offered for stack (column)");
    });

    test("row mode: adds the wrap control", async function (assert) {
      stubWireframe(this.owner, { mode: "row" });
      await render(<template><InspectorLayoutForm /></template>);

      assert
        .dom("input[name='wireframe-layout-wrap']")
        .exists("row offers the wrap segmented control");
      assert.dom(".d-toggle-switch").exists("reverse toggle renders");
    });

    test("grid mode: justify-items, align-content, and dense", async function (assert) {
      stubWireframe(this.owner, { mode: "grid" });
      await render(<template><InspectorLayoutForm /></template>);

      assert
        .dom("input[name='wireframe-layout-justify-items']")
        .exists("justify-items segmented renders");
      assert
        .dom("input[name='wireframe-layout-align-content']")
        .exists("align-content segmented renders");
      assert.dom(".d-toggle-switch").exists("dense toggle renders");
      assert
        .dom("input[name='wireframe-layout-wrap']")
        .doesNotExist("no wrap control in grid mode");
    });

    test("toggling reverse writes the arg through the service", async function (assert) {
      stubWireframe(this.owner, { mode: "row" });
      await render(<template><InspectorLayoutForm /></template>);

      await click(".d-toggle-switch__checkbox");

      const service = this.owner.lookup("service:wireframe-workspace");
      assert.deepEqual(service.updateSelectedArgCalls, [
        { name: "reverse", value: true },
      ]);
    });

    test("surfaces a service validation error on its field", async function (assert) {
      stubWireframe(
        this.owner,
        { mode: "stack" },
        { align: [{ message: "Bad alignment value" }] }
      );
      await render(<template><InspectorLayoutForm /></template>);

      assert
        .dom(".wireframe-layout-form")
        .includesText(
          "Bad alignment value",
          "the field error pushed by the service renders in the form"
        );
    });
  }
);
