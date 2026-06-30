import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector-form";

class StubWireframeService extends Service {
  #blockData;

  #nonFieldErrors;

  constructor(owner, blockData, { nonFieldErrors = [] } = {}) {
    super(owner);
    this.#blockData = blockData;
    this.#nonFieldErrors = nonFieldErrors;
    this.updateSelectedArgCalls = [];
  }

  // The stub is registered as service:wireframe-layout-query too, so a
  // component injecting wireframeLayoutQuery resolves these query methods.
  get layoutQuery() {
    return this;
  }

  get selectedBlockData() {
    return this.#blockData;
  }

  // The form syncs field errors via `selectedBlockFieldErrors`; empty
  // map means the sync is a no-op when a test isn't exercising
  // validation.
  get selectedBlockFieldErrors() {
    return {};
  }

  get selectedBlockNonFieldErrors() {
    return this.#nonFieldErrors;
  }

  get selectedBlockHasErrors() {
    return false;
  }

  get selectedBlockKey() {
    return null;
  }

  get structuralVersion() {
    return 0;
  }

  findEntryAndOutletSync() {
    return null;
  }

  updateSelectedArg(name, value) {
    this.updateSelectedArgCalls.push({ name, value });
  }

  partLockForSelection() {
    return null;
  }

  toggleConditionsDetached() {}
}

function stubWireframe(owner, blockData, options) {
  const stub = new StubWireframeService(owner, blockData, options);
  owner.unregister("service:wireframe-workspace");
  owner.register("service:wireframe-workspace", stub, { instantiate: false });
  owner.unregister("service:wireframe-selection");
  owner.register("service:wireframe-selection", stub, { instantiate: false });
  owner.unregister("service:wireframe-layout-query");
  owner.register("service:wireframe-layout-query", stub, {
    instantiate: false,
  });
  // The form writes arg edits through the inspector-args service; point it at the
  // same stub so `updateSelectedArgCalls` records them.
  owner.unregister("service:wireframe-inspector-args");
  owner.register("service:wireframe-inspector-args", stub, {
    instantiate: false,
  });
}

module(
  "Integration | Wireframe | InspectorForm | image arg control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders the custom image field for a type:image arg", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: {
              type: "image",
              ui: { label: "Image" },
            },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".wireframe-image-field")
        .exists("the custom InspectorImageField renders");
      assert
        .dom(".wireframe-image-field__tab")
        .exists("the Upload/URL tab strip is rendered");
      assert
        .dom(".file-uploader")
        .exists("UppyImageUploader is mounted on the default Upload tab");
    });

    test("dark variant section is omitted when allowDark is false", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: {
              type: "image",
              allowDark: false,
              ui: { label: "Image" },
            },
          },
        },
        argsSnapshot: {
          image: { url: "/uploads/cat.png", width: 400, height: 300 },
        },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".wireframe-image-field__dark")
        .doesNotExist("no dark <details> when allowDark is false");
    });

    test("dark variant section renders when allowDark is true", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: {
              type: "image",
              allowDark: true,
              ui: { label: "Image" },
            },
          },
        },
        argsSnapshot: {
          image: { url: "/uploads/cat.png", width: 400, height: 300 },
        },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".wireframe-image-field__dark")
        .exists("dark <details> section is rendered");
    });

    test("URL tab swaps the uploader for a text input", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: { type: "image", ui: { label: "Image" } },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      await click(".wireframe-image-field__tab:nth-of-type(2)");
      assert
        .dom(".wireframe-image-field__url-input")
        .exists("URL input replaces the uploader on tab switch");
      assert
        .dom(".file-uploader")
        .doesNotExist("uploader is unmounted while the URL tab is active");
    });

    test('wraps an "Advanced" group in <details> while leaving other groups flat', async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            title: {
              type: "string",
              ui: { label: "Title" },
            },
            cookieKey: {
              type: "string",
              ui: { label: "Cookie key", group: "Advanced" },
            },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom("details.wireframe-inspector-form__advanced")
        .exists("the Advanced group renders as <details>")
        .doesNotHaveAttribute(
          "open",
          "collapsed by default — no browser-state pre-opening"
        );
      assert
        .dom("details.wireframe-inspector-form__advanced summary")
        .hasText("Advanced");
      assert
        .dom(".form-kit__section")
        .exists("the non-Advanced group still renders as a FormKit section");
    });

    test("renders a CategoryChooser (not a text input) for category-select args", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            categoryId: {
              type: "number",
              ui: { control: "category-select", label: "Category" },
            },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".category-chooser")
        .exists("CategoryChooser mounted for a single-category arg");
      assert
        .dom('.form-kit__field input[type="text"]')
        .doesNotExist("no plain text fallback");
    });

    test("renders a MiniTagChooser for tag-select args", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            tag: {
              type: "string",
              ui: { control: "tag-select", label: "Tag" },
            },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      assert.dom(".mini-tag-chooser").exists();
    });

    test("renders a block-level constraint error as a bare message with no field prefix", async function (assert) {
      // Constraint violations aren't tied to one input, so the inspector
      // routes them through FormKit as form-level (titleless) errors. The
      // summary should show the message on its own — no redundant "Block:"
      // label and no focus-the-field anchor pointing at a missing control.
      stubWireframe(
        this.owner,
        {
          metadata: {
            args: {
              label: { type: "string", ui: { label: "Label" } },
              icon: { type: "string", ui: { label: "Icon" } },
            },
          },
          argsSnapshot: {},
        },
        {
          nonFieldErrors: [
            {
              code: ERROR_CODES.CONSTRAINT_VIOLATION,
              expected: { constraint: "atLeastOne", fields: ["label", "icon"] },
            },
          ],
        }
      );

      await render(<template><InspectorForm /></template>);

      const item = this.element.querySelector(
        ".form-kit__errors-summary-list li"
      );
      assert.dom(item).exists("the constraint error is listed in the summary");
      assert
        .dom(item)
        .hasText(
          'Set at least one of: "label", "icon".',
          "shows the bare constraint message, no 'Block:' prefix"
        );
      assert
        .dom(item.querySelector("a"))
        .doesNotExist("no focus-the-field anchor for a form-level error");
    });

    test("coerces radio-group values back to the schema's declared number type", async function (assert) {
      // Radio inputs hand their selected value back as a string via the
      // browser's change event (HTML inputs only store strings). For a
      // number+enum arg like a heading's `level`, forwarding that string
      // verbatim into the layout breaks the validator ("Arg level must
      // be a number, got string") and corrupts the rendered block.
      stubWireframe(this.owner, {
        metadata: {
          args: {
            level: {
              type: "number",
              default: 2,
              integer: true,
              enum: [1, 2, 3, 4, 5, 6],
              ui: { control: "radio-group", label: "Level" },
            },
          },
        },
        argsSnapshot: { level: 2 },
      });

      await render(<template><InspectorForm /></template>);

      const stub = this.owner.lookup("service:wireframe-workspace");
      await click('input[type="radio"][value="3"]');

      const lastCall = stub.updateSelectedArgCalls.at(-1);
      assert.strictEqual(lastCall.name, "level");
      assert.strictEqual(
        lastCall.value,
        3,
        "value reaches the editor service as a number, not the input's string"
      );
    });
  }
);
