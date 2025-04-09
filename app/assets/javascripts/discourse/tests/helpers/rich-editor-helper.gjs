import { tracked } from "@glimmer/tracking";
import { click, render, settled, waitFor } from "@ember/test-helpers";
import DEditor from "discourse/components/d-editor";

export async function setupRichEditor(assert, markdown, multiToggle = false) {
  const self = new (class {
    @tracked value = markdown;
    @tracked view;
  })();
  const handleSetup = (textManipulation) => {
    self.view = textManipulation.view;
  };

  await render(
    <template>
      <DEditor
        @value={{self.value}}
        @processPreview={{false}}
        @onSetup={{handleSetup}}
      />
    </template>
  );

  if (multiToggle) {
    // ensure toggling to rich editor and back works
    await click(".composer-toggle-switch");
    await click(".composer-toggle-switch");
    await click(".composer-toggle-switch");
  } else {
    await click(".composer-toggle-switch");
  }

  await waitFor(".ProseMirror");
  await settled();

  const editor = document.querySelector(".ProseMirror");

  // typeIn for contentEditable isn't reliable, and is slower
  const tr = self.view.state.tr;
  // insert a paragraph to enforce serialization
  tr.insert(
    tr.doc.content.size,
    self.view.state.schema.node(
      "paragraph",
      null,
      self.view.state.schema.text("X")
    )
  );
  // then delete it
  tr.delete(tr.doc.content.size - 3, tr.doc.content.size);

  self.view.dispatch(tr);

  await settled();

  const html = editor.innerHTML
    // we don't care about some PM-specifics
    .replace(' class="ProseMirror-selectednode"', "")
    .replace('<img class="ProseMirror-separator" alt="">', "")
    .replace('<br class="ProseMirror-trailingBreak">', "")
    // or artifacts
    .replace(' class=""', "")
    // or a trailing-paragraph with an optional <br class="ProseMirror-trailingBreak"> inside
    .replace(/<p>(<br class="ProseMirror-trailingBreak">)?<\/p>$/, "")
    // or the codemark fake cursor
    .replace(
      '<span class="fake-cursor ProseMirror-widget" contenteditable="false"></span>',
      ""
    );

  return [self, html];
}

export async function testMarkdown(
  assert,
  markdown,
  expectedHtml,
  expectedMarkdown,
  multiToggle = false
) {
  const [editorClass, html] = await setupRichEditor(
    assert,
    markdown,
    multiToggle
  );

  assert.strictEqual(html, expectedHtml, `HTML should match for "${markdown}"`);
  assert.strictEqual(
    editorClass.value,
    expectedMarkdown,
    `Markdown should match for "${markdown}"`
  );
}
