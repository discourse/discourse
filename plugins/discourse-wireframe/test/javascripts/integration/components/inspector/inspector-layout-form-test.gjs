import Service from "@ember/service";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Layout from "discourse/blocks/builtin/layout";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorLayoutForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-layout-form";

// The form derives its mode picker and field defaults from the block's real
// schema, so the stub hands it core's actual `layout` metadata rather than an
// empty stand-in — that keeps the picker in step with core's mode enum.
const LAYOUT_METADATA = getBlockMetadata(Layout);
const MODE_ENUM = LAYOUT_METADATA.args.mode.enum;

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
  // mirror it here. `metadata` is core's real `layout` schema, which the form
  // reads for the mode enum, arg defaults, labels, and validation rules.
  get selectedBlockData() {
    return {
      key: "layout:test",
      args: this.#args,
      argsSnapshot: this.#args,
      metadata: LAYOUT_METADATA,
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
  // The form writes arg edits through the inspector-args service and reads grid-shape
  // helpers off the grid-template service; point both at the same stub.
  owner.unregister("service:wireframe-inspector-args");
  owner.register("service:wireframe-inspector-args", stub, {
    instantiate: false,
  });
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

    test("mode picker offers one segment per core mode enum value", async function (assert) {
      stubWireframe(this.owner, { mode: "stack" });
      await render(<template><InspectorLayoutForm /></template>);

      assert
        .dom("input[name='wireframe-layout-mode']")
        .exists(
          { count: MODE_ENUM.length },
          "the picker derives its segments from the block's mode enum"
        );
    });

    test("tiles mode: min-item-width, but no justify-content or auto-collapse", async function (assert) {
      stubWireframe(this.owner, { mode: "tiles" });
      await render(<template><InspectorLayoutForm /></template>);

      // The min-item-width control is the only dimension field with a unit
      // selector (gap is unitless), so the unit `<select>` identifies it.
      assert
        .dom(".wireframe-dimension-field__unit")
        .exists("min-item-width renders with its rem/px unit selector");
      assert
        .dom(".wireframe-layout-form")
        .includesText("Min item width", "the field carries its label");
      assert
        .dom("input[name='wireframe-layout-justify-content']")
        .doesNotExist("justify-content is hidden in tiles (auto-fit columns)");
      assert
        .dom("input[name='wireframe-layout-auto-collapse']")
        .doesNotExist("auto-collapse is hidden in tiles (reflows on its own)");
    });

    test("editing min-item-width writes the arg through the service", async function (assert) {
      stubWireframe(this.owner, { mode: "tiles", minItemWidth: "16rem" });
      await render(<template><InspectorLayoutForm /></template>);

      // The number input commits on `change`, which `fillIn` fires after
      // setting the value; the field reserializes it under its rem unit.
      await fillIn(".wireframe-dimension-field__number", "20");

      const service = this.owner.lookup("service:wireframe-workspace");
      assert.deepEqual(service.updateSelectedArgCalls, [
        { name: "minItemWidth", value: "20rem" },
      ]);
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
