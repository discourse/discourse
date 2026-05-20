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
  }
);
