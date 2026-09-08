import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { simulateExternalDrag } from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import InspectorForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-form";

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
    return this.#blockData.fieldErrors ?? {};
  }

  get selectedBlockNonFieldErrors() {
    return this.#nonFieldErrors;
  }

  get selectedBlockHasErrors() {
    return false;
  }

  get selectedBlockKey() {
    return this.#blockData.key ?? null;
  }

  get structuralVersion() {
    return 0;
  }

  findEntryAndOutletSync() {
    return this.#blockData.key
      ? { entry: { args: this.#blockData.argsSnapshot } }
      : null;
  }

  isGridCellEntry() {
    return this.#blockData.gridCell ?? false;
  }

  updateSelectedArg(name, value) {
    this.updateSelectedArgCalls.push({ name, value });
  }

  partLockForSelection() {
    return this.#blockData.lockedArgs ?? null;
  }

  registerBeforeChange() {
    return () => {};
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

    test("empty image exposes its chooser without a disclosure or dark variant", async function (assert) {
      stubWireframe(this.owner, {
        key: "image-empty",
        gridCell: true,
        metadata: {
          args: {
            image: {
              type: "image",
              required: true,
              allowDark: true,
              allowResize: true,
            },
          },
        },
        argsSnapshot: {},
        fieldErrors: {
          image: [{ code: ERROR_CODES.REQUIRED_MISSING, field: "image" }],
        },
      });
      await render(<template><InspectorForm /></template>);
      assert
        .dom(".wireframe-image-field summary")
        .doesNotExist("nothing must be expanded to add the required image");
      assert
        .dom(".wireframe-image-field__dark")
        .doesNotExist("dark is unavailable until a default exists");
      assert
        .dom(".wireframe-image-field__frame")
        .doesNotExist(
          "frame settings cannot separate the required error from its empty chooser"
        );
      assert
        .dom(".wireframe-image-field .file-uploader input[type=file]")
        .exists("the default upload is directly available");
      assert
        .dom(".form-kit__field.has-error")
        .includesText(
          "Required.",
          "validation remains attached to the default chooser"
        );
    });

    test("closed image sources accept variant-specific drops and show pending and failed uploads", async function (assert) {
      stubWireframe(this.owner, {
        key: "image-drops",
        metadata: { args: { image: { type: "image", allowDark: true } } },
        argsSnapshot: {
          image: {
            source: "upload",
            url: "/default.png",
            dark: { source: "upload", url: "/dark.png" },
          },
        },
      });
      const uploads = [];
      let finish;
      let reportProgress;
      class Upload extends Service {
        uploadImageForArg(file, { onProgress, ...target }) {
          reportProgress = onProgress;
          uploads.push({ file, target });
          return new Promise((resolve) => {
            finish = resolve;
          });
        }
      }
      this.owner.unregister("service:wireframe-image-upload");
      this.owner.register("service:wireframe-image-upload", Upload);
      assert.true(
        this.owner.lookup("service:wireframe-image-upload") instanceof Upload
      );
      await render(<template><InspectorForm /></template>);
      const file = new File(["image"], "replacement.png", {
        type: "image/png",
      });
      for (const [variant, selector] of [
        ["light", ".wireframe-image-field__variant"],
        ["dark", ".wireframe-image-field__dark"],
      ]) {
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        await simulateExternalDrag(`${selector} summary`, { dataTransfer });
        assert.deepEqual(
          uploads.at(-1),
          {
            file,
            target: { blockKey: "image-drops", argName: "image", variant },
          },
          "the drop retains the row's variant and destination"
        );
        assert
          .dom(selector)
          .doesNotHaveAttribute("open", "dropping does not expand the editor");
        assert
          .dom(`${selector} summary`)
          .hasAttribute(
            "aria-busy",
            "true",
            "pending replacement is visible on the closed row"
          );
        assert
          .dom(`${selector} summary progress`)
          .exists("progress is visible while the row stays closed");
        assert
          .dom(`${selector} summary progress`)
          .doesNotHaveAttribute(
            "value",
            "progress is indeterminate before the first upload event"
          );
        for (const progress of [25, 70]) {
          reportProgress?.(progress);
          await settled();
          assert
            .dom(`${selector} summary progress`)
            .hasAttribute(
              "value",
              String(progress),
              "the bar follows actual upload progress"
            );
        }
        const pendingCount = uploads.length;
        await simulateExternalDrag(`${selector} summary`, { dataTransfer });
        assert.strictEqual(
          uploads.length,
          pendingCount,
          "a pending row rejects another drop"
        );
        finish(false);
        await settled();
        assert
          .dom(`${selector} summary progress`)
          .doesNotExist("the progress bar clears when uploading ends");
        assert
          .dom(`${selector} .wireframe-image-field__warning`)
          .exists("a failed upload is visible without expanding");
        assert
          .dom(`${selector} summary`)
          .doesNotHaveAttribute(
            "aria-busy",
            "pending state clears after failure"
          );
      }
      assert.strictEqual(uploads.length, 2, "each drop uploads once");
    });

    test("inspector upload progress forwards Uppy percentages only while pending", async function (assert) {
      stubWireframe(this.owner, {
        key: "image-progress",
        metadata: {},
        argsSnapshot: {},
      });
      const service = this.owner.lookup("service:wireframe-image-upload");
      const handlers = new Map();
      const progress = [];
      sinon.stub(service, "beginReplacement").returns(() => {});
      sinon.stub(UppyUpload.prototype, "setup").get(
        () =>
          function () {
            this.uppyWrapper = {
              uppyInstance: {
                on: (name, callback) => handlers.set(name, callback),
              },
            };
          }
      );
      sinon.stub(UppyUpload.prototype, "addFiles").get(() => () => {});
      const teardown = sinon.stub(UppyUpload.prototype, "teardown");
      const pending = service.uploadImageForArg(new File(["x"], "image.png"), {
        blockKey: "image-progress",
        argName: "image",
        onProgress: (value) => progress.push(value),
      });
      handlers.get("progress")?.(25);
      handlers.get("progress")?.(70);
      assert.deepEqual(
        progress,
        [25, 70],
        "the service relays the upload's percentages"
      );
      handlers.get("upload-error")();
      await pending;
      handlers.get("progress")?.(90);
      assert.deepEqual(
        progress,
        [25, 70],
        "late events cannot change a finished upload"
      );
      assert.true(teardown.calledOnce, "the upload is cleaned up");
    });

    test("source previews stay compact and group both variants before composition", async function (assert) {
      stubWireframe(this.owner, {
        key: "image-1",
        metadata: {
          args: {
            image: { type: "image", allowDark: true, allowComposition: true },
          },
        },
        argsSnapshot: {
          image: {
            source: "upload",
            url: "/uploads/default.png",
            width: 800,
            height: 600,
            dark: {
              source: "upload",
              url: "/uploads/dark.png",
              width: 800,
              height: 600,
            },
          },
        },
      });

      await render(<template><InspectorForm /></template>);

      assert
        .dom(".wireframe-image-field__source img")
        .exists({ count: 2 }, "both sources have previews");
      assert
        .dom(".wireframe-image-field__variant")
        .doesNotHaveAttribute("open", "default chooser starts collapsed");
      assert
        .dom(".wireframe-image-field__dark")
        .doesNotHaveAttribute(
          "open",
          "even a populated dark chooser starts collapsed"
        );
      assert
        .dom(".wireframe-image-field__dark + .wireframe-image-composition")
        .exists("dark source is adjacent to default, before composition");
      await click(".wireframe-image-field__variant summary");
      assert
        .dom(".wireframe-image-field__variant")
        .hasAttribute("open", "", "default chooser expands on request");
      assert
        .dom(".wireframe-image-field__variant .file-uploader.has-image")
        .doesNotExist("the upload chooser does not repeat the source preview");
      assert
        .dom(".wireframe-image-field__variant .wireframe-image-field__remove")
        .hasText(
          "Remove image",
          "uploaded sources use the common remove action"
        );
      await click(".wireframe-image-field__variant summary");
      assert
        .dom(".wireframe-image-field__variant")
        .doesNotHaveAttribute("open", "chooser can be collapsed again");
      await click(".wireframe-image-field__dark summary");
      assert
        .dom(".wireframe-image-field__dark")
        .hasAttribute("open", "", "dark chooser expands independently");
      assert
        .dom(".wireframe-image-field__dark .file-uploader.has-image")
        .doesNotExist("the dark chooser does not repeat its preview either");
      assert
        .dom(".wireframe-image-field__dark .wireframe-image-field__remove")
        .hasText("Remove image", "dark uploads use the same remove action");
      await click('.wireframe-image-field__dark [role="tab"]:last-child');
      assert
        .dom(".wireframe-image-field__dark .wireframe-image-field__remove")
        .hasText("Remove image", "removal stays available in URL mode");
    });

    test("only explicitly named groups have headings", async function (assert) {
      stubWireframe(this.owner, {
        metadata: {
          args: {
            title: { type: "string", ui: { label: "Title" } },
            count: { type: "number", ui: { label: "Count", group: "Content" } },
            note: { type: "string", ui: { label: "Note", group: "Advanced" } },
          },
        },
        argsSnapshot: {},
      });
      await render(<template><InspectorForm /></template>);
      assert
        .dom(".form-kit__section-title")
        .exists({ count: 1 }, "implicit General has no heading");
      assert
        .dom(".form-kit__section-title")
        .hasText("Content", "explicit group is retained");
      assert
        .dom(".wireframe-inspector-form__advanced summary")
        .hasText("Advanced", "advanced disclosure is retained");
    });

    test("an explicitly named General group retains its heading and field rules", async function (assert) {
      stubWireframe(this.owner, {
        lockedArgs: ["note"],
        metadata: {
          args: {
            title: { type: "string", ui: { label: "Title", group: "General" } },
            note: { type: "string", ui: { label: "Note", group: "General" } },
            extra: {
              type: "string",
              ui: {
                label: "Extra",
                conditional: { arg: "title", equals: "show" },
              },
            },
          },
        },
        argsSnapshot: { title: "hidden", note: "Locked content" },
      });
      await render(<template><InspectorForm /></template>);
      assert
        .dom(".form-kit__section-title")
        .hasText("General", "an author-supplied General title is meaningful");
      assert
        .dom('input[name="title"]')
        .isNotDisabled("ordinary fields stay editable");
      assert
        .dom('input[name="note"]')
        .isDisabled("composite locks remain enforced");
      assert
        .dom('input[name="extra"]')
        .doesNotExist("conditional fields remain hidden");
    });

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
        key: "image-with-default",
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
