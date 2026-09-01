import { click, find, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - quote extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic quote": [
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
        `<aside class="quote" data-full="false"><blockquote><p>This is a quote.</p></blockquote></aside><p>This is not</p>`,
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
      ],
      "quote with username": [
        `[quote="User"]\nQuoted text.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-full="false"><div class="title" contenteditable="false">User:</div><blockquote><p>Quoted text.</p></blockquote></aside>`,
        `[quote="User"]\nQuoted text.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID": [
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-topic="456" data-full="false"><div class="title" contenteditable="false">User:</div><blockquote><p>Quoted from a topic.</p></blockquote></aside>`,
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID and post number": [
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-post="123" data-topic="456" data-full="false"><div class="title" contenteditable="false">User:</div><blockquote><p>Full quote example.</p></blockquote></aside>`,
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]\n\n`,
      ],
      "quote with display name and username": [
        `[quote="Full Name, post:123, topic:456, username:user123"]\nQuoted with display name.\n\n[/quote]`,
        `<aside class="quote" data-username="user123" data-post="123" data-topic="456" data-full="false" data-display-name="Full Name"><div class="title" contenteditable="false">Full Name:</div><blockquote><p>Quoted with display name.</p></blockquote></aside>`,
        `[quote="Full Name, post:123, topic:456, username:user123"]\nQuoted with display name.\n\n[/quote]\n\n`,
      ],
      "quote with display name containing comma": [
        `[quote="Last, First, post:123, topic:456, username:user123"]\nComma name.\n\n[/quote]`,
        `<aside class="quote" data-username="user123" data-post="123" data-topic="456" data-full="false" data-display-name="Last, First"><div class="title" contenteditable="false">Last, First:</div><blockquote><p>Comma name.</p></blockquote></aside>`,
        `[quote="Last, First, post:123, topic:456, username:user123"]\nComma name.\n\n[/quote]\n\n`,
      ],
      "quote with full:true": [
        `[quote="User, post:1, topic:2, full:true"]\nFull quote.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-post="1" data-topic="2" data-full="true"><div class="title" contenteditable="false">User:</div><blockquote><p>Full quote.</p></blockquote></aside>`,
        `[quote="User, post:1, topic:2, full:true"]\nFull quote.\n\n[/quote]\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });

    test("avatar from the host editor's topic", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `[quote="Full Name, post:123, topic:456, username:quoted_user"]\nQuoted text.\n\n[/quote]`,
        {
          markdownOptions: {
            lookupAvatarTemplateByPostNumber: (postNumber, topicId) =>
              postNumber === 123 && topicId === 456
                ? "/images/avatar/{size}.png"
                : null,
          },
        }
      );

      assert
        .dom("aside.quote .title img.avatar")
        .hasAttribute(
          "src",
          /^\/images\/avatar\/\d+\.png$/,
          "the avatar is rendered at a resolved size"
        );
      assert
        .dom("aside.quote .title")
        .hasText("Full Name:", "the display name is shown");

      assert.strictEqual(
        editor.value,
        `[quote="Full Name, post:123, topic:456, username:quoted_user"]\nQuoted text.\n\n[/quote]\n\n`,
        "avatar does not leak into the serialized markdown"
      );
    });

    test("no avatar when the quoted post is not in the topic", async function (assert) {
      await setupRichEditor(
        assert,
        `[quote="User, post:99, topic:11"]\nQuoted text.\n\n[/quote]`,
        {
          markdownOptions: {
            lookupAvatarTemplateByPostNumber: () => undefined,
          },
        }
      );

      assert
        .dom("aside.quote .title img.avatar")
        .doesNotExist("no avatar is rendered for an unresolved post");
      assert
        .dom("aside.quote .title")
        .hasText("User:", "the username is still shown");
    });

    test("quote without a username renders no title", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `[quote="removed_user"]\nQuoted text.\n\n[/quote]`
      );

      const { view } = editor;
      // the quote node sits at the document root in this fixture
      view.dispatch(
        view.state.tr.setNodeMarkup(0, null, {
          ...view.state.doc.nodeAt(0).attrs,
          username: null,
        })
      );
      await settled();

      assert
        .dom("aside.quote .title")
        .doesNotExist("the header is removed with the username");
      assert
        .dom("aside.quote blockquote")
        .hasText("Quoted text.", "the quoted content is kept");
    });

    test("quote can be selected and removed", async function (assert) {
      await setupRichEditor(assert, `[quote="User"]\nQuoted text.\n\n[/quote]`);

      await click("aside.quote .title");

      assert
        .dom("aside.quote")
        .hasClass("ProseMirror-selectednode", "the quote is selected");

      await triggerKeyEvent(".ProseMirror", "keydown", "Backspace");

      assert.dom("aside.quote").doesNotExist("the selected quote is removed");
    });

    test("the header is not rebuilt while typing in the quote", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        `[quote="User, post:1, topic:2"]\nText.\n\n[/quote]`,
        {
          markdownOptions: {
            lookupAvatarTemplateByPostNumber: () => "/a/{size}.png",
          },
        }
      );

      const title = find("aside.quote .title");
      const avatar = find("aside.quote .title img");

      const { view } = editor;
      view.dispatch(view.state.tr.insertText("x", 3));
      await settled();

      assert.strictEqual(
        title,
        find("aside.quote .title"),
        "the title element is reused"
      );
      assert.strictEqual(
        avatar,
        find("aside.quote .title img"),
        "the avatar element is reused"
      );
    });

    test("a hostile avatar template cannot inject markup", async function (assert) {
      await setupRichEditor(
        assert,
        `[quote="User, post:1, topic:2"]\nQuoted text.\n\n[/quote]`,
        {
          markdownOptions: {
            lookupAvatarTemplateByPostNumber: () =>
              `/a/{size}.png" onerror="throw new Error('injected')`,
          },
        }
      );

      assert
        .dom("aside.quote .title img.avatar")
        .doesNotHaveAttribute("onerror", "the template cannot add attributes");
      assert
        .dom("aside.quote .title script")
        .doesNotExist("the template cannot add elements");
    });

    test("quote survives repeated node view teardown", async function (assert) {
      await testMarkdown(
        assert,
        `[quote="User"]\nQuoted text.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-full="false"><div class="title" contenteditable="false">User:</div><blockquote><p>Quoted text.</p></blockquote></aside>`,
        `[quote="User"]\nQuoted text.\n\n[/quote]\n\n`,
        { multiToggle: true }
      );
    });
  }
);
