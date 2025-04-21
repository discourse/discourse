import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  clearRichEditorExtensions,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module("Integration | Component | prosemirror-editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(() => clearRichEditorExtensions());
  hooks.afterEach(() => resetRichEditorExtensions());

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

  test("supports registered nodeSpec/parser/serializer", async function (assert) {
    this.siteSettings.rich_editor = true;

    withPluginApi("2.1.0", (api) => {
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
    this.siteSettings.rich_editor = true;

    withPluginApi("2.1.0", (api) => {
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
    this.siteSettings.rich_editor = true;

    const state = {};

    withPluginApi("2.1.0", (api) => {
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
    this.siteSettings.rich_editor = true;

    const state = {};

    withPluginApi("2.1.0", (api) => {
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
