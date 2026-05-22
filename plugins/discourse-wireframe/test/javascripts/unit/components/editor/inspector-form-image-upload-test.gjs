import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector-form";

class StubWireframeService extends Service {
  constructor(owner, blockData) {
    super(owner);
    this._blockData = blockData;
    this.updateSelectedArgCalls = [];
  }

  get selectedBlockData() {
    return this._blockData;
  }

  // InspectorValidationBanner reads these; the form mounts the banner
  // unconditionally above the sections, so the stub has to cover them
  // even when we're not exercising validation in a given test.
  get validationWarnings() {
    return [];
  }

  get selectedBlockKey() {
    return null;
  }

  get structuralVersion() {
    return 0;
  }

  _findEntryAndOutletSync() {
    return null;
  }

  updateSelectedArg(name, value) {
    this.updateSelectedArgCalls.push({ name, value });
  }
}

function stubWireframe(owner, blockData) {
  owner.unregister("service:wireframe");
  owner.register(
    "service:wireframe",
    new StubWireframeService(owner, blockData),
    { instantiate: false }
  );
}

module(
  "Integration | Wireframe | InspectorForm | image-upload control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders an image upload control for an image-upload schema arg", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: {
              type: "object",
              ui: { control: "image-upload", label: "Image" },
            },
          },
        },
        argsSnapshot: {},
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".form-kit__control-image")
        .exists("FKControlImage is rendered without crashing");
      assert
        .dom(".file-uploader")
        .exists("UppyImageUploader's file-uploader markup is in the DOM");
    });

    test("renders the uploaded image preview when args carry a full upload object", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            image: {
              type: "object",
              ui: { control: "image-upload", label: "Image" },
            },
          },
        },
        argsSnapshot: {
          image: { url: "/uploads/cat.png", width: 400, height: 300 },
        },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".file-uploader")
        .hasClass(
          "has-image",
          "the uploader is in the has-image state, not no-image"
        );
      assert
        .dom(".file-uploader a.lightbox")
        .hasAttribute(
          "href",
          /\/uploads\/cat\.png$/,
          "the preview href resolves to the uploaded URL, not [object Object]"
        );
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

      const stub = this.owner.lookup("service:wireframe");
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
