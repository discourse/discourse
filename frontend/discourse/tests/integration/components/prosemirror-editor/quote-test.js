import { settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - quote extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/u/:username/card.json", () => response(404, {}));
    });

    Object.entries({
      "basic quote": [
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
        `<aside class="quote" data-full="false"><blockquote><p>This is a quote.</p></blockquote></aside><p>This is not</p>`,
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
      ],
      "quote with username": [
        `[quote="User"]\nQuoted text.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-full="false"><div class="title">User:</div><blockquote><p>Quoted text.</p></blockquote></aside>`,
        `[quote="User"]\nQuoted text.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID": [
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-topic="456" data-full="false"><div class="title">User:</div><blockquote><p>Quoted from a topic.</p></blockquote></aside>`,
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID and post number": [
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-post="123" data-topic="456" data-full="false"><div class="title">User:</div><blockquote><p>Full quote example.</p></blockquote></aside>`,
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]\n\n`,
      ],
      "quote with display name and username": [
        `[quote="Full Name, post:123, topic:456, username:user123"]\nQuoted with display name.\n\n[/quote]`,
        `<aside class="quote" data-username="user123" data-post="123" data-topic="456" data-full="false" data-display-name="Full Name"><div class="title">Full Name:</div><blockquote><p>Quoted with display name.</p></blockquote></aside>`,
        `[quote="Full Name, post:123, topic:456, username:user123"]\nQuoted with display name.\n\n[/quote]\n\n`,
      ],
      "quote with display name containing comma": [
        `[quote="Last, First, post:123, topic:456, username:user123"]\nComma name.\n\n[/quote]`,
        `<aside class="quote" data-username="user123" data-post="123" data-topic="456" data-full="false" data-display-name="Last, First"><div class="title">Last, First:</div><blockquote><p>Comma name.</p></blockquote></aside>`,
        `[quote="Last, First, post:123, topic:456, username:user123"]\nComma name.\n\n[/quote]\n\n`,
      ],
      "quote with full:true": [
        `[quote="User, post:1, topic:2, full:true"]\nFull quote.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-post="1" data-topic="2" data-full="true"><div class="title">User:</div><blockquote><p>Full quote.</p></blockquote></aside>`,
        `[quote="User, post:1, topic:2, full:true"]\nFull quote.\n\n[/quote]\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });

    test("quote with a resolvable user avatar", async function (assert) {
      // username unique to this test, as avatar lookups are cached module-wide
      pretender.get("/u/avatared_user/card.json", () =>
        response({
          user: { avatar_template: "/images/avatar.png?size={size}" },
        })
      );

      const [editor] = await setupRichEditor(
        assert,
        `[quote="Full Name, post:123, topic:456, username:avatared_user"]\nQuoted text.\n\n[/quote]`
      );

      await waitFor("aside.quote .title img.avatar");

      assert
        .dom("aside.quote .title img.avatar")
        .hasAttribute("src", /^\/images\/avatar\.png/);
      assert.dom("aside.quote .title").hasText("Full Name:");

      assert.strictEqual(
        editor.value,
        `[quote="Full Name, post:123, topic:456, username:avatared_user"]\nQuoted text.\n\n[/quote]\n\n`,
        "avatar does not leak into the serialized markdown"
      );
    });

    test("avatar follows a change of quoted user", async function (assert) {
      pretender.get("/u/renamed_from/card.json", () =>
        response({ user: { avatar_template: "/images/from.png?size={size}" } })
      );
      pretender.get("/u/renamed_to/card.json", () =>
        response({ user: { avatar_template: "/images/to.png?size={size}" } })
      );

      const [editor] = await setupRichEditor(
        assert,
        `[quote="renamed_from"]\nQuoted text.\n\n[/quote]`
      );
      await waitFor("aside.quote .title img.avatar");

      const { view } = editor;
      let quotePos = null;
      view.state.doc.descendants((node, pos) => {
        if (node.type.name === "quote") {
          quotePos = pos;
        }
      });

      view.dispatch(
        view.state.tr.setNodeMarkup(quotePos, null, {
          ...view.state.doc.nodeAt(quotePos).attrs,
          username: "renamed_to",
        })
      );
      await settled();

      assert.dom("aside.quote .title").hasText("renamed_to:");
      assert
        .dom("aside.quote .title img.avatar")
        .hasAttribute("src", /^\/images\/to\.png/);
    });

    test("quote survives repeated node view teardown", async function (assert) {
      await testMarkdown(
        assert,
        `[quote="User"]\nQuoted text.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-full="false"><div class="title">User:</div><blockquote><p>Quoted text.</p></blockquote></aside>`,
        `[quote="User"]\nQuoted text.\n\n[/quote]\n\n`,
        true
      );
    });
  }
);
