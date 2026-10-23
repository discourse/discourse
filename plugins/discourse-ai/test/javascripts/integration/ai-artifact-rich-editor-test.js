import {
  click,
  fillIn,
  settled,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { metaModifier } from "discourse/tests/helpers/qunit-helpers";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/discourse-ai/discourse/lib/ai-artifact-rich-editor-extension";

module(
  "Integration | Component | prosemirror-editor - AI artifact extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      this.siteSettings.discourse_ai_enabled = true;
      pretender.get(
        "/discourse-ai/ai-bot/artifact-shares/:share_key/metadata.json",
        () => response(404, {})
      );
      pretender.get("/discourse-ai/ai-bot/artifacts/:id/metadata.json", () =>
        response(404, {})
      );
      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    test("shows configured embed options on the card", async function (assert) {
      await setupRichEditor(
        assert,
        '[ai-artifact share="shared" autorun="true" height="2000" seamless="true"]'
      );

      assert
        .dom(".composer-ai-artifact__kind")
        .doesNotExist("omits the redundant artifact kind subtitle");
      assert
        .dom('.composer-ai-artifact__options [data-option="autorun"]')
        .hasText(
          "Run automatically: On",
          "shows the configured autorun preference"
        );
      assert
        .dom('.composer-ai-artifact__options [data-option="height"]')
        .hasText("Height: 2000 px", "shows the configured height");
      assert
        .dom('.composer-ai-artifact__options [data-option="seamless"]')
        .hasText("Seamless: On", "shows the configured seamless preference");
      assert
        .dom(".ai-artifact-options-modal")
        .doesNotExist("does not open a dialog");
      assert
        .dom(".ProseMirror iframe")
        .doesNotExist("does not run the artifact");
    });

    test("distinguishes default and disabled options on the card", async function (assert) {
      await setupRichEditor(
        assert,
        '[ai-artifact share="shared" autorun="false"]'
      );

      assert
        .dom('.composer-ai-artifact__options [data-option="autorun"]')
        .hasText(
          "Run automatically: Off",
          "keeps explicit off distinct from default"
        );
      assert
        .dom('.composer-ai-artifact__options [data-option="height"]')
        .hasText("Height: Default", "shows the default height");
      assert
        .dom('.composer-ai-artifact__options [data-option="seamless"]')
        .hasText("Seamless: Default", "shows the default seamless preference");
    });

    for (const tag of [
      '[ai-artifact share="abc_123" autorun="true"]',
      '[ai-artifact share="abc_123" autorun="false"]',
      '[ai-artifact id="123" version="2" autorun="true"]',
      '[ai-artifact id="9999999999999999999" autorun="false"]',
      '[ai-artifact share="abc_123" height="2000" seamless="true"]',
      '[ai-artifact id="7" height="42" seamless="false"]',
    ]) {
      test(`round-trips ${tag} without running it`, async function (assert) {
        await testMarkdown(
          assert,
          tag,
          () => {
            assert
              .dom(".ProseMirror .composer-ai-artifact")
              .includesText("AI artifact");
            assert
              .dom(".ProseMirror .composer-ai-artifact")
              .doesNotIncludeText(tag);
            assert
              .dom(".composer-ai-artifact__edit")
              .exists("options are always reachable");
            assert.dom(".ProseMirror .ai-artifact").doesNotExist();
            assert.dom(".ProseMirror iframe").doesNotExist();
          },
          tag
        );
      });
    }

    test("preserves surrounding text and switches between editor modes", async function (assert) {
      const tag = '[ai-artifact id="7" version="3" autorun="false"]';
      const markdown = `Before\n\n${tag}\n\nAfter`;
      const [editor] = await setupRichEditor(assert, markdown, {
        multiToggle: true,
      });

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.strictEqual(editor.value, markdown);

      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.strictEqual(editor.value, markdown);
    });

    test("preserves an artifact and following paragraph in one blockquote", async function (assert) {
      const markdown = '> [ai-artifact id="1"]\n>\n> after';
      const [editor] = await setupRichEditor(assert, markdown, {
        multiToggle: true,
      });

      assert
        .dom(".ProseMirror blockquote")
        .exists({ count: 1 }, "the artifact and paragraph share a blockquote");
      assert
        .dom(".ProseMirror blockquote .composer-ai-artifact")
        .exists("the artifact remains nested");
      assert
        .dom(".ProseMirror blockquote p")
        .hasText("after", "the following paragraph remains nested");
      assert.strictEqual(
        editor.value,
        markdown,
        "serialization keeps the quote open"
      );

      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert
        .dom(".ProseMirror blockquote")
        .exists({ count: 1 }, "reparsing keeps one blockquote");
      assert
        .dom(".ProseMirror blockquote .composer-ai-artifact")
        .exists("reparsing keeps the artifact nested");
      assert
        .dom(".ProseMirror blockquote p")
        .hasText("after", "reparsing keeps the paragraph nested");
    });

    test("preserves an artifact and following paragraph in one list item", async function (assert) {
      const markdown = '- [ai-artifact id="1"]\n\n  after';
      const [editor] = await setupRichEditor(assert, markdown, {
        multiToggle: true,
      });

      assert
        .dom(".ProseMirror li")
        .exists({ count: 1 }, "the artifact and paragraph share a list item");
      assert
        .dom(".ProseMirror li .composer-ai-artifact")
        .exists("the artifact remains nested");
      assert
        .dom(".ProseMirror li p")
        .hasText("after", "the following paragraph remains nested");
      assert.strictEqual(
        editor.value,
        '* [ai-artifact id="1"]\n\n  after',
        "serialization keeps the list open"
      );

      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert
        .dom(".ProseMirror li")
        .exists({ count: 1 }, "reparsing keeps one item");
      assert
        .dom(".ProseMirror li .composer-ai-artifact")
        .exists("reparsing keeps the artifact nested");
      assert
        .dom(".ProseMirror li p")
        .hasText("after", "reparsing keeps the paragraph nested");
    });

    test("does not add extra spacing between list items", async function (assert) {
      const markdown = '- [ai-artifact id="1"]\n- after';
      const [editor] = await setupRichEditor(assert, markdown, {
        multiToggle: true,
      });

      assert.dom(".ProseMirror li").exists({ count: 2 }, "both items render");
      assert
        .dom(".ProseMirror li:first-child .composer-ai-artifact")
        .exists("the artifact is in the first item");
      assert
        .dom(".ProseMirror li:last-child p")
        .hasText("after", "the next item is separate");
      assert.strictEqual(
        editor.value,
        '* [ai-artifact id="1"]\n\n* after',
        "serialization adds only one blank line between items"
      );

      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert.dom(".ProseMirror li").exists({ count: 2 }, "both items reparse");
      assert
        .dom(".ProseMirror li:first-child .composer-ai-artifact")
        .exists("the artifact stays in the first item");
      assert
        .dom(".ProseMirror li:last-child p")
        .hasText("after", "the second item stays separate");
    });

    test("keeps inline tags and code inert", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        'Inline [ai-artifact id="7" height="2000" seamless="true"] text.\n\n`[ai-artifact id="7" height="2000"]`\n\n```\n[ai-artifact id="7" height="2000" seamless="true"]\n```'
      );
      assert.dom(".ProseMirror .composer-ai-artifact").doesNotExist();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(editor.value.includes('[ai-artifact id="7" height="2000"]'));
    });

    test("pastes cooked share and legacy layout attributes safely", async function (assert) {
      const [editor] = await setupRichEditor(assert, "Before");
      editor.view.pasteHTML(
        '<div class="ai-artifact" data-ai-artifact-id="7" data-ai-artifact-version="2" data-ai-artifact-autorun="true" data-ai-artifact-height="400" data-ai-artifact-width="600" data-ai-artifact-seamless="true"></div>'
      );
      await settled();

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror .ai-artifact").doesNotExist();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(editor.value.includes('data-ai-artifact-height="400"'));
      assert.true(editor.value.includes('data-ai-artifact-width="600"'));
      assert.true(editor.value.includes('data-ai-artifact-seamless="true"'));
      assert.true(editor.value.includes('data-ai-artifact-autorun="true"'));
      assert.true(editor.value.includes("Before"));

      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert.true(editor.value.includes('data-ai-artifact-height="400"'));
      assert.true(editor.value.includes('data-ai-artifact-width="600"'));
      assert.true(editor.value.includes('data-ai-artifact-seamless="true"'));
      assert.dom(".ProseMirror iframe").doesNotExist();
    });

    test("reopens legacy artifact HTML as a card while leaving other HTML and code inert", async function (assert) {
      const legacy =
        '<div class="ai-artifact" data-ai-artifact-id="7" data-ai-artifact-version="2" data-ai-artifact-height="400" data-ai-artifact-width="600" data-ai-artifact-seamless="true"></div>';
      const [editor] = await setupRichEditor(
        assert,
        `${legacy}\n\n<div class="other">Hello</div>\n\n\`\`\`html\n${legacy}\n\`\`\``,
        { multiToggle: true }
      );
      assert
        .dom(".ProseMirror .composer-ai-artifact")
        .exists("legacy HTML is an artifact card");
      assert
        .dom(".ProseMirror .html-block")
        .exists({ count: 1 }, "unrelated HTML remains generic");
      assert
        .dom(".ProseMirror pre:not(.html-block) code")
        .exists("fenced HTML remains code");
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(
        editor.value.includes('data-ai-artifact-width="600"'),
        "legacy width is preserved"
      );
      assert.true(
        editor.value.includes('data-ai-artifact-height="400"'),
        "legacy height is preserved"
      );
      assert.true(
        editor.value.includes('data-ai-artifact-seamless="true"'),
        "legacy seamless is preserved"
      );
      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert
        .dom(".ProseMirror .composer-ai-artifact")
        .exists("reopening retains the artifact card");
      assert
        .dom(".ProseMirror .html-block")
        .exists({ count: 1 }, "only unrelated HTML remains generic");
      assert.dom(".ProseMirror iframe").doesNotExist();
    });

    test("keeps malformed layout tags and unrecognized HTML inert", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        '[ai-artifact id="7" height="2001"]\n\n[ai-artifact share="key" seamless="1"]\n\n<div class="ai-artifact" data-ai-artifact-id="7" onclick="alert(1)"></div>'
      );
      assert.dom(".ProseMirror .composer-ai-artifact").doesNotExist();
      assert
        .dom(".ProseMirror .html-block")
        .exists("unknown HTML stays generic");
      assert.dom(".ProseMirror iframe, .ProseMirror script").doesNotExist();
      assert.true(
        editor.value.includes('height="2001"'),
        "invalid tag is retained"
      );
      assert.true(
        editor.value.includes('seamless="1"'),
        "invalid boolean is retained"
      );
    });

    test("reopens encoded legacy attributes without double-escaping", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        '<div class="ai-artifact" data-ai-artifact-share-key="shared" data-ai-artifact-width="600&amp;auto"></div>',
        { multiToggle: true }
      );
      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.strictEqual(
        editor.value,
        '<div class="ai-artifact" data-ai-artifact-share-key="shared" data-ai-artifact-width="600&amp;auto"></div>',
        "the escaped legacy width is preserved"
      );
      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
    });

    test("pastes cooked share as a compact tag", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");
      editor.view.pasteHTML(
        '<div class="ai-artifact" data-ai-artifact-share-key="shared" data-ai-artifact-autorun="false"></div>'
      );
      await settled();

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(
        editor.value.includes('[ai-artifact share="shared" autorun="false"]')
      );
    });

    test("normalizes legacy autorun values without dropping the artifact", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");
      editor.view.pasteHTML(
        '<div class="ai-artifact" data-ai-artifact-id="7" data-ai-artifact-autorun="1" data-ai-artifact-height="350"></div>'
      );
      await settled();

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(editor.value.includes('autorun="true"'));
      assert.true(editor.value.includes('height="350"'));
    });

    test("pastes a standalone plain-text tag into an empty paragraph", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");
      editor.view.pasteHTML('<p>[ai-artifact id="7" autorun="true"]</p>');
      await settled();

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(editor.value.includes('[ai-artifact id="7" autorun="true"]'));
    });

    test("typing a standalone tag creates a safe artifact block", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");
      const { view } = editor;
      view.dispatch(
        view.state.tr.insertText('[ai-artifact id="7" autorun="true"')
      );
      const pos = view.state.selection.from;
      view.someProp("handleTextInput", (handler) =>
        handler(view, pos, pos, "]")
      );
      await settled();

      assert.dom(".ProseMirror .composer-ai-artifact").exists();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.true(editor.value.includes('[ai-artifact id="7" autorun="true"]'));
    });
    test("uses only inert title metadata and never renders executable HTML", async function (assert) {
      pretender.get(
        "/discourse-ai/ai-bot/artifact-shares/shared/metadata.json",
        () => response({ name: '<img src=x onerror="alert(1)"> My art' })
      );
      const [editor] = await setupRichEditor(
        assert,
        '[ai-artifact share="shared"]'
      );
      await waitFor(".composer-ai-artifact__title");
      await settled();

      assert
        .dom(".composer-ai-artifact__title")
        .hasText('<img src=x onerror="alert(1)"> My art');
      assert
        .dom(".ProseMirror img, .ProseMirror iframe, .ProseMirror script")
        .doesNotExist();
      assert.strictEqual(editor.value, '[ai-artifact share="shared"]');
    });

    test("edits source identity, version, autorun and height in one undoable change", async function (assert) {
      const original = '[ai-artifact id="7" version="3" autorun="false"]';
      const [editor] = await setupRichEditor(
        assert,
        '[ai-artifact id="7" version="3" autorun="false"]',
        { withMenus: true }
      );
      await click(".composer-ai-artifact__edit");
      assert.dom(".ai-artifact-options-modal").exists();
      await fillIn('[data-name="reference"] input', "12");
      await fillIn('[data-name="version"] input', "4");
      await formKit().field("autorun").select("true");
      await fillIn('[data-name="height"] input', "2000");
      await formKit().field("seamless").select("true");
      await click(".ai-artifact-options-modal__apply");

      assert.dom(".ai-artifact-options-modal").doesNotExist();
      assert.strictEqual(
        editor.value,
        '[ai-artifact id="12" version="4" autorun="true" height="2000" seamless="true"]',
        "layout edits serialize as a compact tag"
      );
      assert
        .dom('.composer-ai-artifact__options [data-option="height"]')
        .hasText("Height: 2000 px", "refreshes the static summary after Apply");
      assert.dom(".ProseMirror .html-block").doesNotExist();
      assert.dom(".ProseMirror iframe").doesNotExist();
      assert.dom(".ProseMirror").isFocused("focus returns to the editor");

      await triggerKeyEvent(".ProseMirror", "keydown", "Z", metaModifier);
      assert.strictEqual(editor.value, original, "one undo reverts the edit");
      await triggerKeyEvent(".ProseMirror", "keydown", "Z", {
        ...metaModifier,
        shiftKey: true,
      });
      assert.strictEqual(
        editor.value,
        '[ai-artifact id="12" version="4" autorun="true" height="2000" seamless="true"]',
        "redo restores the compact edit"
      );
      await click(".composer-toggle-switch");
      await click(".composer-toggle-switch");
      assert
        .dom(".ProseMirror .composer-ai-artifact")
        .exists("the reopened tag is a card");
      assert
        .dom(".ProseMirror .html-block, .ProseMirror iframe")
        .doesNotExist();
    });

    test("keeps share identity, stored preference, and legacy width on no-op edit", async function (assert) {
      this.siteSettings.ai_artifact_security = "strict";
      const [editor] = await setupRichEditor(assert, "", { withMenus: true });
      editor.view.pasteHTML(
        '<div class="ai-artifact" data-ai-artifact-share-key="shared" data-ai-artifact-autorun="true" data-ai-artifact-width="600"></div>'
      );
      await settled();
      const original = editor.value;
      await click(".composer-ai-artifact__edit");
      assert
        .dom('[data-name="version"]')
        .doesNotExist("a share has no source version");
      assert
        .dom(".ai-artifact-options-modal__policy")
        .includesText("requires a click");
      await click(".ai-artifact-options-modal__apply");
      assert.strictEqual(editor.value, original);
      assert.true(editor.value.includes('data-ai-artifact-width="600"'));
      assert.true(editor.value.includes('data-ai-artifact-autorun="true"'));
    });

    test("keeps long source IDs and legacy layout on unrelated changes", async function (assert) {
      const [editor] = await setupRichEditor(assert, "", { withMenus: true });
      editor.view.pasteHTML(
        '<div class="ai-artifact" data-ai-artifact-id="9999999999999999999" data-ai-artifact-version="1234567890123456789" data-ai-artifact-height="2600" data-ai-artifact-width="640" data-ai-artifact-seamless="1"></div>'
      );
      await settled();
      await click(".composer-ai-artifact__edit");
      await formKit().field("autorun").select("false");
      await click(".ai-artifact-options-modal__apply");
      assert.true(
        editor.value.includes('data-ai-artifact-id="9999999999999999999"')
      );
      assert.true(
        editor.value.includes('data-ai-artifact-version="1234567890123456789"')
      );
      assert.true(editor.value.includes('data-ai-artifact-height="2600"'));
      assert.true(editor.value.includes('data-ai-artifact-width="640"'));
      assert.true(editor.value.includes('data-ai-artifact-seamless="1"'));
    });

    test("accepts this site's copied share link but rejects an external link", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        '[ai-artifact share="shared"]',
        { withMenus: true }
      );
      await click(".composer-ai-artifact__edit");
      await fillIn(
        '[data-name="reference"] input',
        `${window.location.origin}/discourse-ai/ai-bot/artifact-shares/another`
      );
      await click(".ai-artifact-options-modal__apply");
      assert.strictEqual(editor.value, '[ai-artifact share="another"]');

      await click(".composer-ai-artifact__edit");
      await fillIn(
        '[data-name="reference"] input',
        "https://example.org/discourse-ai/ai-bot/artifact-shares/other"
      );
      await click(".ai-artifact-options-modal__apply");
      assert
        .dom(".ai-artifact-options-modal")
        .exists("external URLs are rejected");
      assert.strictEqual(editor.value, '[ai-artifact share="another"]');
    });

    test("keeps the absent autorun preference distinct from explicit off", async function (assert) {
      const [editor] = await setupRichEditor(assert, '[ai-artifact id="7"]', {
        withMenus: true,
      });
      await click(".composer-ai-artifact__edit");
      assert.dom('[data-name="reference"]').doesNotIncludeText("optional");
      assert.dom('[data-name="autorun"] select').hasValue("default");
      assert.dom('[data-name="seamless"] select').hasValue("default");
      await formKit().field("autorun").select("false");
      await click(".ai-artifact-options-modal__apply");
      assert.strictEqual(editor.value, '[ai-artifact id="7" autorun="false"]');

      await click(".composer-ai-artifact__edit");
      await formKit().field("autorun").select("default");
      await click(".ai-artifact-options-modal__apply");
      assert.strictEqual(editor.value, '[ai-artifact id="7"]');
    });

    test("cancel and invalid references leave the original embed untouched", async function (assert) {
      const [editor] = await setupRichEditor(assert, '[ai-artifact id="7"]', {
        withMenus: true,
      });
      const original = editor.value;
      await click(".composer-ai-artifact__edit");
      await fillIn('[data-name="reference"] input', "other");
      await click(".ai-artifact-options-modal__cancel");
      assert.strictEqual(editor.value, original);
      assert.dom(".ProseMirror").isFocused("cancel returns focus");

      await click(".composer-ai-artifact__edit");
      await fillIn('[data-name="reference"] input', 'bad ref"<');
      await fillIn('[data-name="height"] input', "-1");
      await click(".ai-artifact-options-modal__apply");
      assert
        .dom(".ai-artifact-options-modal")
        .exists("invalid form stays open");
      assert.strictEqual(editor.value, original, "no partial update");
      assert.dom(".form-kit__errors").exists("validation is shown");
    });
  }
);
