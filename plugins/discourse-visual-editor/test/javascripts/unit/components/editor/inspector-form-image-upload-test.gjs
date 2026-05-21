import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorForm from "discourse/plugins/discourse-visual-editor/discourse/components/editor/inspector-form";

class StubVisualEditorService extends Service {
  constructor(owner, blockData) {
    super(owner);
    this._blockData = blockData;
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

  updateSelectedArg() {}
}

function stubVisualEditor(owner, blockData) {
  owner.unregister("service:visual-editor");
  owner.register(
    "service:visual-editor",
    new StubVisualEditorService(owner, blockData),
    { instantiate: false }
  );
}

module(
  "Integration | Visual Editor | InspectorForm | image-upload control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders an image upload control for an image-upload schema arg", async function (assert) {
      stubVisualEditor(this.owner, {
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
      stubVisualEditor(this.owner, {
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
      stubVisualEditor(this.owner, {
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
        .dom("details.visual-editor-inspector-form__advanced")
        .exists("the Advanced group renders as <details>")
        .doesNotHaveAttribute(
          "open",
          "collapsed by default — no browser-state pre-opening"
        );
      assert
        .dom("details.visual-editor-inspector-form__advanced summary")
        .hasText("Advanced");
      assert
        .dom(".form-kit__section")
        .exists("the non-Advanced group still renders as a FormKit section");
    });

    test("renders a CategoryChooser (not a text input) for category-select args", async function (assert) {
      stubVisualEditor(this.owner, {
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
      stubVisualEditor(this.owner, {
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
  }
);
