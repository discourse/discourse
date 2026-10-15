import Service from "@ember/service";
import { click, fillIn, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-form";
import InspectorMetadataSection from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-metadata-section";
import InspectorPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-panel";
import InspectorRawJson from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-raw-json";

/**
 * A permissive stub for the wireframe service. Only the surface the
 * inspector components read is implemented; everything returns a safe
 * default so a single stub can back several different component renders.
 */
class StubWireframeService extends Service {
  #blockData;

  constructor(owner, blockData) {
    super(owner);
    this.#blockData = blockData;
    this.updateSelectedArgCalls = [];
    this.updateSelectedEntryIdCalls = [];
    this.removeBlockCalls = [];
  }

  // The stub is registered as service:wireframe-layout-query too, so a
  // component injecting wireframeLayoutQuery resolves these query methods.
  get layoutQuery() {
    return this;
  }

  get selectedBlockData() {
    return this.#blockData;
  }

  get selectedBlockKey() {
    return this.#blockData?.key ?? "wf:stub:1";
  }

  get selectedBlockRawEntry() {
    return this.#blockData?.rawEntry ?? null;
  }

  get selectedBlockFieldErrors() {
    return this.#blockData?.fieldErrors ?? {};
  }

  get selectedBlockNonFieldErrors() {
    return this.#blockData?.nonFieldErrors ?? [];
  }

  get selectedBlockHasErrors() {
    return (
      Object.keys(this.selectedBlockFieldErrors).length > 0 ||
      this.selectedBlockNonFieldErrors.length > 0
    );
  }

  get conditionsDetached() {
    return false;
  }

  isOutletRoot() {
    return false;
  }

  partLockForSelection() {
    return null;
  }

  toggleConditionsDetached() {}

  updateSelectedArg(name, value) {
    this.updateSelectedArgCalls.push({ name, value });
  }

  updateSelectedEntryId(value) {
    this.updateSelectedEntryIdCalls.push(value);
    return { ok: true };
  }

  replaceSelectedEntryRaw() {
    return true;
  }

  removeBlock(key) {
    this.removeBlockCalls.push(key);
  }

  removeBlocks(keys) {
    this.removeBlockCalls.push(...keys);
  }
}

module("Integration | Wireframe | inspector metadata", function (hooks) {
  setupRenderingTest(hooks);

  test("disclosures follow transient defaults and omit empty groups", async function (assert) {
    const group = { name: "identity", label: "Speaker", collapsed: true };
    const blockData = {
      name: "test-card",
      isRegistered: true,
      argsSnapshot: {},
      metadata: {
        args: {
          enabled: { type: "boolean", default: true },
          presentation: {
            type: "string",
            default: "above",
            ui: { hidden: true },
          },
          name: {
            type: "string",
            ui: {
              group,
              conditional: {
                all: [
                  { arg: "enabled", equals: true },
                  { arg: "presentation", oneOf: ["above", "below"] },
                ],
              },
            },
          },
        },
      },
    };
    stubWireframe(this.owner, blockData);
    const stub = this.owner.lookup("service:wireframe-selection");
    this.owner.unregister("service:wireframe-inspector-args");
    this.owner.register("service:wireframe-inspector-args", stub, {
      instantiate: false,
    });
    await render(<template><InspectorForm /></template>);
    assert.dom('[data-inspector-group="identity"] summary').hasText("Speaker");
    assert
      .dom('#control-enabled [role="switch"]')
      .hasAttribute(
        "aria-checked",
        "true",
        "the control and its visibility predicate share the schema default"
      );
    assert
      .dom('[data-inspector-group="identity"]')
      .doesNotHaveAttribute("open");
    assert.dom('input[name="name"]').exists("closed fields remain mounted");
    await click('[data-inspector-group="identity"] summary');
    await fillIn('input[name="name"]', "Sam");
    await click('#control-enabled [role="switch"]');
    assert
      .dom('[data-inspector-group="identity"]')
      .doesNotExist("an empty group leaves no heading");
    assert.deepEqual(
      blockData.argsSnapshot,
      {},
      "visibility did not depend on replacing the selection snapshot"
    );
    await click('#control-enabled [role="switch"]');
    assert
      .dom('input[name="name"]')
      .hasValue("Sam", "toggling does not clear optional content");
    assert.deepEqual(
      stub.updateSelectedArgCalls.map((call) => call.name),
      ["name", "enabled", "enabled"],
      "disclosure state is never written into block args"
    );
  });

  test("errors make gated fields reachable inside closed disclosures", async function (assert) {
    stubWireframe(this.owner, {
      name: "test-card",
      isRegistered: true,
      argsSnapshot: { enabled: false },
      metadata: {
        args: {
          enabled: { type: "boolean" },
          name: {
            type: "string",
            ui: {
              label: "Name",
              group: { name: "identity", label: "Speaker", collapsed: true },
              conditional: { arg: "enabled", equals: true },
            },
          },
        },
      },
      fieldErrors: { name: [{ code: "required", message: "Required" }] },
    });
    await render(<template><InspectorForm /></template>);
    assert
      .dom('input[name="name"]')
      .exists("an error overrides normal visibility");
    await click('.form-kit__errors-summary-list a[href="#control-name"]');
    assert.dom('[data-inspector-group="identity"]').hasAttribute("open");
    assert.strictEqual(document.activeElement, find('input[name="name"]'));
  });
});

function stubWireframe(owner, blockData) {
  owner.unregister("service:wireframe-workspace");
  const stub = new StubWireframeService(owner, blockData);
  owner.register("service:wireframe-workspace", stub, { instantiate: false });
  owner.unregister("service:wireframe-layout-query");
  owner.register("service:wireframe-layout-query", stub, {
    instantiate: false,
  });
  // The inspector reads the selection identity off the selection service.
  owner.unregister("service:wireframe-selection");
  owner.register("service:wireframe-selection", stub, { instantiate: false });
  // The inspector removes through the injected block-mutations service; back it
  // with the same stub so `removeBlock` still records onto `removeBlockCalls`.
  owner.unregister("service:wireframe-block-mutations");
  owner.register("service:wireframe-block-mutations", stub, {
    instantiate: false,
  });
}

module(
  "Integration | Wireframe | Inspector | unregistered block read-only",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the args form shows live values but disables the controls", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        metadata: null,
        argsSnapshot: { title: "Hello" },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom('.wireframe-inspector-form input[name="title"]')
        .exists("the inferred field still renders so the value is visible")
        .hasValue("Hello", "the live value is shown")
        .isDisabled("but the control is read-only for an unregistered block");
    });

    test("a registered block keeps its args controls editable", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:heading",
        isRegistered: true,
        metadata: {
          args: { title: { type: "string", ui: { label: "Title" } } },
        },
        argsSnapshot: { title: "Hello" },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom('.wireframe-inspector-form input[name="title"]')
        .isNotDisabled("a registered block's fields stay editable");
    });

    test("an undefined isRegistered flag is treated as editable", async function (assert) {
      // Existing selection data predating the flag must not regress to
      // read-only — only an explicit `false` locks the inspector.
      stubWireframe(this.owner, {
        name: "wf:legacy",
        metadata: { args: { title: { type: "string" } } },
        argsSnapshot: { title: "Hello" },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom('.wireframe-inspector-form input[name="title"]')
        .isNotDisabled("absent flag means editable");
    });

    test("the panel renders the read-only notice for an unregistered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        metadata: null,
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__unregistered-notice")
        .exists("the notice explains why the fields are locked");
      assert
        .dom(
          ".wireframe-inspector__unregistered-notice.form-kit__alert.alert-error"
        )
        .exists("the notice is rendered as a FormKit error alert");
      assert
        .dom(
          ".wireframe-inspector__unregistered-notice .d-icon-triangle-exclamation"
        )
        .exists("the notice carries the error icon");
      assert
        .dom(".wireframe-inspector__unregistered-notice strong")
        .hasText("Unregistered block", "the notice leads with a heading");
    });

    test("the notice's remove button removes the selected block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        key: "wf:gone:1",
        isRegistered: false,
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__unregistered-notice-action")
        .exists("the notice offers a remove action");

      await click(".wireframe-inspector__unregistered-notice-action");

      const service = this.owner.lookup("service:wireframe-workspace");
      assert.deepEqual(
        service.removeBlockCalls,
        ["wf:gone:1"],
        "clicking removes the selected block by its key"
      );
    });

    test("the panel omits the notice for a registered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:heading",
        isRegistered: true,
        metadata: { args: { title: { type: "string" } } },
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__unregistered-notice")
        .doesNotExist("no notice when the editor knows the block");
    });

    test("the args form hides the validation summary for an unregistered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        argsSnapshot: { title: "Hello" },
        nonFieldErrors: [{ code: "unregistered-block", value: "wf:gone" }],
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".form-kit__errors-summary")
        .doesNotExist(
          "the panel notice owns this message, so the form summary is suppressed"
        );
    });

    test("the args form keeps the validation summary for a registered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:heading",
        isRegistered: true,
        metadata: { args: { title: { type: "string" } } },
        argsSnapshot: { title: "Hello" },
        nonFieldErrors: [
          { code: "invalid-block", message: "Something failed" },
        ],
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".form-kit__errors-summary")
        .exists("registered blocks still surface their validation errors");
    });

    test("the Args tab drops its error flag for an unregistered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
        nonFieldErrors: [{ code: "unregistered-block", value: "wf:gone" }],
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__tab.--has-errors")
        .doesNotExist(
          "the notice already signals the problem, so the tab isn't flagged too"
        );
    });

    test("the raw JSON textarea is read-only for an unregistered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        rawEntry: { block: "wf:gone", args: { title: "Hello" } },
      });

      await render(<template><InspectorRawJson /></template>);

      assert
        .dom(".wireframe-inspector-raw-json__textarea")
        .isDisabled("the raw entry can't be edited for an unregistered block");
    });

    test("the raw JSON textarea stays editable for a registered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:heading",
        isRegistered: true,
        rawEntry: { block: "wf:heading", args: { title: "Hello" } },
      });

      await render(<template><InspectorRawJson /></template>);

      assert
        .dom(".wireframe-inspector-raw-json__textarea")
        .isNotDisabled("registered blocks keep the raw editor available");
    });

    test("the metadata id input is read-only for an unregistered block", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        // A non-empty id auto-expands the section so the input renders.
        id: "hero",
      });

      await render(<template><InspectorMetadataSection /></template>);

      assert
        .dom(".wireframe-inspector-metadata__input")
        .isDisabled("the block id can't be edited for an unregistered block");
    });
  }
);
