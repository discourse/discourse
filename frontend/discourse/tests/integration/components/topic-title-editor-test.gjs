import EmberObject from "@ember/object";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicTitleEditor from "discourse/components/topic-title-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | TopicTitleEditor", function (hooks) {
  setupRenderingTest(hooks);

  for (const isEditingLocalization of [false, true]) {
    test(`preserves the paste caret with localization=${isEditingLocalization}`, async function (assert) {
      const buffered = EmberObject.create({ title: "Before  after" });
      this.translationTitle = buffered.title;
      const onTranslationTitleChange = (title) =>
        this.set("translationTitle", title);

      await render(
        <template>
          <TopicTitleEditor
            @buffered={{buffered}}
            @bufferedTitle={{buffered.title}}
            @isEditingLocalization={{isEditingLocalization}}
            @onTranslationTitleChange={{onTranslationTitleChange}}
            @translationLocale="ja"
            @translationTitle={{this.translationTitle}}
          />
        </template>
      );

      const textarea = this.element.querySelector("#edit-title");
      textarea.value = "Before first\n\nsecond after";
      textarea.setSelectionRange(20, 20);
      await triggerEvent(textarea, "input");

      assert.dom(textarea).hasValue("Before first second after");
      assert.strictEqual(textarea.selectionStart, 19);
      assert.strictEqual(textarea.selectionEnd, 19);
      assert.strictEqual(
        isEditingLocalization ? this.translationTitle : buffered.title,
        "Before first second after"
      );
    });
  }

  test("keeps a long unbroken title within a narrow editor", async function (assert) {
    const buffered = EmberObject.create({ title: "x".repeat(200) });

    await render(
      <template>
        <div class="edit-topic-title" style="width: 320px;">
          <TopicTitleEditor
            @buffered={{buffered}}
            @bufferedTitle={{buffered.title}}
          />
        </div>
      </template>
    );

    const editor = this.element.querySelector(".edit-topic-title");
    const textarea = this.element.querySelector("#edit-title");
    assert.true(
      textarea.getBoundingClientRect().width <= editor.clientWidth,
      "the textarea fits inside the editor"
    );
    assert.true(
      textarea.scrollHeight <= textarea.clientHeight + 1,
      "the wrapped title is fully visible"
    );
  });
});
