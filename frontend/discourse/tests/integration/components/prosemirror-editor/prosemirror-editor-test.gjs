import { click, find, render, settled, waitFor } from "@ember/test-helpers";
import { cacheShortUploadUrl, resetCache } from "pretty-text/upload-short-url";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import DMenus from "discourse/float-kit/components/d-menus";
import {
  clearRichEditorExtensions,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import grid from "discourse/static/prosemirror/extensions/grid";
import image from "discourse/static/prosemirror/extensions/image";
import defaultExtensions from "discourse/static/prosemirror/extensions/register-default";
import uploadPlaceholder from "discourse/static/prosemirror/extensions/upload-placeholder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module("Integration | Component | ProsemirrorEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(() => clearRichEditorExtensions());
  hooks.afterEach(() => {
    resetCache();
    resetRichEditorExtensions();
  });

  test("renders the editor", async function (assert) {
    await render(<template><ProsemirrorEditor /></template>);
    assert.dom(".ProseMirror").exists("it renders the ProseMirror editor");
  });

  test("renders the editor with a null initial value", async function (assert) {
    await render(<template><ProsemirrorEditor @value={{null}} /></template>);
    assert.dom(".ProseMirror").exists("it renders the ProseMirror editor");
  });

  test("renders the editor with a markdown initial value", async function (assert) {
    await render(
      <template>
        <ProsemirrorEditor
          @value="the **chickens** have come home to roost _bobby boucher_!"
        />
      </template>
    );
    assert.dom(".ProseMirror").exists("it renders the ProseMirror editor");
    assert
      .dom(".ProseMirror em")
      .exists("it renders the italic markdown as HTML");
    assert
      .dom(".ProseMirror strong")
      .exists("it renders the strong markdown as HTML");
  });

  test("auto-grids image filenames using generic placeholders", async function (assert) {
    withPluginApi((api) => {
      api.registerRichEditorExtension(grid);
      api.registerRichEditorExtension(image);
      api.registerRichEditorExtension(uploadPlaceholder);
    });

    let textManipulation;
    const handleSetup = (value) => {
      textManipulation = value;
    };

    await render(
      <template><ProsemirrorEditor @onSetup={{handleSetup}} /></template>
    );

    const files = [1, 2, 3].map((number) => ({
      id: `image-${number}`,
      name: `IMG_${number}.HEIC`,
      data: new File(["image"], `IMG_${number}.HEIC`),
    }));

    files.forEach((file) => {
      textManipulation.placeholder.insert(file);
    });
    textManipulation.autoGridImages(files.map((file) => file.name));
    await settled();

    assert
      .dom(".composer-image-grid")
      .exists({ count: 1 }, "generic placeholders are wrapped immediately");
    assert
      .dom(".composer-image-grid .upload-placeholder.--file")
      .exists(
        { count: 3 },
        "all pending images use generic placeholders inside the grid"
      );

    const shortUrls = files.map((file, index) => {
      const shortUrl = `upload://heic-grid-${index}.jpeg`;
      const resolvedUrl = `/images/heic-grid-${index}.jpeg`;
      cacheShortUploadUrl(shortUrl, { url: resolvedUrl });
      textManipulation.placeholder.success(
        file,
        `![IMG_${index + 1}](${shortUrl})`
      );
      return shortUrl;
    });

    let replacementImage;
    textManipulation.view.state.doc.descendants((node) => {
      if (
        node.type.name === "image" &&
        node.attrs.originalSrc === shortUrls[0]
      ) {
        replacementImage = node;
        return false;
      }
    });
    assert.strictEqual(
      replacementImage?.attrs.src,
      "/images/heic-grid-0.jpeg",
      "the final image URL is resolved in the upload-success transaction"
    );

    await settled();

    assert
      .dom(".composer-image-grid")
      .exists({ count: 1 }, "the completed images preserve the grid");
    assert
      .dom(".composer-image-grid .composer-image-node")
      .exists({ count: 3 }, "all completed images are in the grid");
  });

  test("renders the editor with minimum extensions", async function (assert) {
    const minimumExtensions = [
      { nodeSpec: { doc: { content: "inline*" }, text: { group: "inline" } } },
    ];

    await render(
      <template>
        <ProsemirrorEditor
          @includeDefault={{false}}
          @extensions={{minimumExtensions}}
        />
      </template>
    );

    assert.dom(".ProseMirror").exists("it renders the ProseMirror editor");
  });

  test("uses node actions from the editor's extensions", async function (assert) {
    let globalRuns = 0;
    let localRuns = 0;

    withPluginApi((api) => {
      api.registerRichEditorExtension({
        nodeActions: {
          paragraph: () => [
            {
              label: "Global action",
              className: "composer-node-menu__global-action",
              action: () => globalRuns++,
            },
          ],
        },
      });
    });

    const extensions = [
      ...defaultExtensions,
      {
        nodeActions: {
          paragraph: () => [
            {
              label: "Local action",
              className: "composer-node-menu__local-action",
              action: () => localRuns++,
            },
          ],
        },
      },
    ];

    await render(
      <template>
        <ProsemirrorEditor @extensions={{extensions}} @value="Paragraph" />
        <DMenus />
        <ModalContainer />
      </template>
    );

    const block = find(".ProseMirror > p");
    const bounds = block.getBoundingClientRect();
    block.parentElement.dispatchEvent(
      new PointerEvent("pointermove", {
        bubbles: true,
        clientX: bounds.left + 20,
        clientY: bounds.top + 6,
      })
    );
    await settled();
    await click(".composer-drag-handle");
    await waitFor(".composer-node-menu__local-action");

    assert
      .dom(".composer-node-menu__global-action")
      .doesNotExist("globally registered actions stay out of this editor");

    await click(".composer-node-menu__local-action");

    assert.strictEqual(localRuns, 1, "the editor-local action runs");
    assert.strictEqual(globalRuns, 0, "the global action does not run");
  });

  test("supports registered nodeSpec/parser/serializer", async function (assert) {
    withPluginApi((api) => {
      // Multiple parsers can be registered for the same node type
      api.registerRichEditorExtension({
        parse: { wrap_open() {}, wrap_close() {} },
      });

      api.registerRichEditorExtension({
        nodeSpec: {
          marquee: {
            content: "block*",
            group: "block",
            parseDOM: [{ tag: "marquee" }],
            toDOM: () => ["marquee", 0],
          },
        },
        parse: {
          wrap_open(state, token) {
            if (token.attrGet("data-wrap") === "marquee") {
              state.openNode(state.schema.nodes.marquee);
              return true;
            }
          },
          wrap_close(state) {
            if (state.top().type.name === "marquee") {
              state.closeNode();
              return true;
            }
          },
        },
        serializeNode: {
          marquee(state, node) {
            state.write("[wrap=marquee]\n");
            state.renderContent(node);
            state.write("[/wrap]\n\n");
          },
        },
      });

      api.registerRichEditorExtension({
        parse: { wrap_open() {}, wrap_close() {} },
      });
    });

    await testMarkdown(
      assert,
      "[wrap=marquee]\nHello\n[wrap=marquee]\nWorld\n[/wrap]\nInner\n[/wrap]\n\nText",
      "<marquee><p>Hello</p><marquee><p>World</p></marquee><p>Inner</p></marquee><p>Text</p>",
      "[wrap=marquee]\nHello\n\n[wrap=marquee]\nWorld\n\n[/wrap]\n\nInner\n\n[/wrap]\n\nText"
    );
  });

  test("supports registered markSpec/parser/serializer", async function (assert) {
    withPluginApi((api) => {
      api.registerRichEditorExtension({
        // just for testing purpose - our actual hashtag is a node, not a mark
        markSpec: {
          hashtag: {
            parseDOM: [{ tag: "span.hashtag-raw" }],
            toDOM: () => ["span", { class: "hashtag-raw" }],
          },
        },
        parse: {
          span_open(state, token, tokens, i) {
            if (token.attrGet("class") === "hashtag-raw") {
              // Remove the # from the content
              tokens[i + 1].content = tokens[i + 1].content.slice(1);
              state.openMark(state.schema.marks.hashtag.create());
              return true;
            }
          },
          span_close(state) {
            state.closeMark(state.schema.marks.hashtag);
          },
        },
        serializeMark: { hashtag: { open: "#", close: "" } },
      });
    });

    await testMarkdown(
      assert,
      "Hello #tag #test",
      '<p>Hello <span class="hashtag-raw">tag</span> <span class="hashtag-raw">test</span></p>',
      "Hello #tag #test"
    );
  });

  test("supports registered nodeViews", async function (assert) {
    const state = {};

    withPluginApi((api) => {
      api.registerRichEditorExtension({
        nodeViews: {
          paragraph: class CustomNodeView {
            constructor() {
              this.dom = document.createElement("p");
              this.dom.className = "custom-p";

              state.updated = true;
            }
          },
        },
      });
    });

    await render(<template><ProsemirrorEditor /></template>);

    assert.true(
      state.updated,
      "it calls the update method of the custom node view"
    );

    assert.dom(".custom-p").exists("it renders the custom node view for p");
  });

  test("supports registered plugins with array, object or function", async function (assert) {
    const state = {};

    withPluginApi((api) => {
      // plugins can be an array
      api.registerRichEditorExtension({
        plugins: [
          {
            view() {
              state.plugin1 = true;
              return {};
            },
          },
        ],
      });

      // or the plugin object itself
      api.registerRichEditorExtension({
        plugins: {
          view() {
            state.plugin2 = true;
            return {};
          },
        },
      });

      // or a function that returns the plugin object
      api.registerRichEditorExtension({
        plugins: ({ pmState: { Plugin } }) =>
          new Plugin({
            view() {
              state.plugin3 = true;
              return {};
            },
          }),
      });
    });

    await render(<template><ProsemirrorEditor /></template>);

    assert.true(state.plugin1, "plugin1's view fn was called");
    assert.true(state.plugin2, "plugin2's view fn was called");
    assert.true(state.plugin3, "plugin3's view fn was called");
  });
});
