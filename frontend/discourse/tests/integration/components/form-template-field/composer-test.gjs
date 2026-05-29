import { getOwner } from "@ember/owner";
import { render, settled, triggerEvent, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import FormComposer from "discourse/components/form-template-field/composer";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function fakeUppy() {
  return { textManipulation: null };
}

module(
  "Integration | Component | FormTemplateField | Composer",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      sinon.restore();
    });

    function stubAllowUpload(context, value) {
      const composerService = getOwner(context).lookup("service:composer");
      sinon.stub(composerService, "allowUpload").value(value);
    }

    test("renders the markdown editor", async function (assert) {
      stubAllowUpload(this, true);

      await render(<template><FormComposer @onChange={{noop}} /></template>);

      assert
        .dom("[data-field-type='composer'] .d-editor-input")
        .exists("the markdown editor renders");
    });

    test("assigns textManipulation when uppyComposerUpload is provided", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      assert.true(
        uppy.textManipulation?.textarea instanceof HTMLTextAreaElement,
        "textManipulation reflects the active editor's text manipulation"
      );
    });

    test("does not assign textManipulation when allowUpload is false", async function (assert) {
      stubAllowUpload(this, false);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      assert.strictEqual(
        uppy.textManipulation,
        null,
        "textManipulation is left untouched"
      );
    });

    test("re-claims the upload target on focusin", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const initialTextManipulation = uppy.textManipulation;
      uppy.textManipulation = "trampled-by-another-field";

      await triggerEvent(".d-editor-input", "focusin");

      assert.strictEqual(
        uppy.textManipulation,
        initialTextManipulation,
        "focusin restores this field's textManipulation as the upload target"
      );
    });

    test("re-claims the upload target on dragenter", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const initialTextManipulation = uppy.textManipulation;
      uppy.textManipulation = "trampled-by-another-field";

      await triggerEvent(".d-editor-input", "dragenter");

      assert.strictEqual(
        uppy.textManipulation,
        initialTextManipulation,
        "dragenter restores this field's textManipulation as the upload target"
      );
    });

    test("re-claims the upload target on dragover", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const initialTextManipulation = uppy.textManipulation;
      uppy.textManipulation = "trampled-by-another-field";

      await triggerEvent(".d-editor-input", "dragover");

      assert.strictEqual(
        uppy.textManipulation,
        initialTextManipulation,
        "dragover restores this field's textManipulation as the upload target"
      );
    });

    test("dragging onto an unfocused field claims its upload target", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const textareas = document.querySelectorAll(
        "[data-field-type='composer'] .d-editor-input"
      );

      await triggerEvent(textareas[0], "focusin");
      const fieldATextManipulation = uppy.textManipulation;

      await triggerEvent(textareas[1], "dragenter");

      assert.notStrictEqual(
        uppy.textManipulation,
        fieldATextManipulation,
        "dragenter on field B switches the upload target away from field A without requiring focus"
      );
    });

    test("removes claim listeners when the component is destroyed", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);
      this.set("show", true);

      await render(
        <template>
          {{#if this.show}}
            <FormComposer
              @onChange={{noop}}
              @uppyComposerUpload={{this.uppy}}
            />
          {{/if}}
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const textarea = document.querySelector(
        "[data-field-type='composer'] .d-editor-input"
      );

      this.set("show", false);
      await settled();

      uppy.textManipulation = "sentinel";

      for (const event of ["focusin", "dragenter", "dragover"]) {
        textarea.dispatchEvent(new Event(event, { bubbles: true }));
      }

      assert.strictEqual(
        uppy.textManipulation,
        "sentinel",
        "claim listeners no longer fire after the component is destroyed"
      );
    });

    test("multiple fields route uploads to the focused field", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.textManipulation);

      const textareas = document.querySelectorAll(
        "[data-field-type='composer'] .d-editor-input"
      );
      assert.strictEqual(textareas.length, 2, "both fields render textareas");

      await triggerEvent(textareas[0], "focusin");
      const fieldATextManipulation = uppy.textManipulation;

      await triggerEvent(textareas[1], "focusin");
      const fieldBTextManipulation = uppy.textManipulation;

      assert.notStrictEqual(
        fieldATextManipulation,
        fieldBTextManipulation,
        "each field has its own textManipulation"
      );

      await triggerEvent(textareas[0], "focusin");
      assert.strictEqual(
        uppy.textManipulation,
        fieldATextManipulation,
        "focusing field A again restores its textManipulation"
      );
    });

    test("composer:replace-text replaces in composerValue and fires onChange", async function (assert) {
      stubAllowUpload(this, true);

      const onChange = sinon.spy();
      this.set("onChange", onChange);
      this.set("initialValue", "before ![image|10x10](upload://abc.png) after");

      await render(
        <template>
          <FormComposer
            @id="field-1"
            @value={{this.initialValue}}
            @onChange={{this.onChange}}
          />
        </template>
      );

      const appEvents = getOwner(this).lookup("service:app-events");
      appEvents.trigger(
        "composer:replace-text",
        "![image|10x10](upload://abc.png)",
        "![image|10x10, 75%](upload://abc.png)"
      );

      await settled();

      const expected = "before ![image|10x10, 75%](upload://abc.png) after";
      assert.dom("input[name='field-1']").hasValue(expected);
      assert.dom(".d-editor-input").hasValue(expected);
      assert.true(onChange.called, "onChange fires after the replacement");
    });

    test("composer:replace-text only replaces the first occurrence", async function (assert) {
      stubAllowUpload(this, true);

      this.set(
        "initialValue",
        "![image|10x10](upload://abc.png) and ![image|10x10](upload://abc.png)"
      );

      await render(
        <template>
          <FormComposer
            @id="field-1"
            @value={{this.initialValue}}
            @onChange={{noop}}
          />
        </template>
      );

      const appEvents = getOwner(this).lookup("service:app-events");
      appEvents.trigger(
        "composer:replace-text",
        "![image|10x10](upload://abc.png)",
        "![image|10x10, 75%](upload://abc.png)"
      );

      await settled();

      const expected =
        "![image|10x10, 75%](upload://abc.png) and ![image|10x10](upload://abc.png)";
      assert.dom("input[name='field-1']").hasValue(expected);
      assert.dom(".d-editor-input").hasValue(expected);
    });

    test("composer:replace-text is a no-op when the field does not contain the markdown", async function (assert) {
      stubAllowUpload(this, true);

      const onChange = sinon.spy();
      this.set("onChange", onChange);
      this.set("initialValue", "no images here");

      await render(
        <template>
          <FormComposer
            @id="field-1"
            @value={{this.initialValue}}
            @onChange={{this.onChange}}
          />
        </template>
      );

      const appEvents = getOwner(this).lookup("service:app-events");
      appEvents.trigger(
        "composer:replace-text",
        "![image|10x10](upload://abc.png)",
        "![image|10x10, 75%](upload://abc.png)"
      );

      await settled();

      assert.dom("input[name='field-1']").hasValue("no images here");
      assert.dom(".d-editor-input").hasValue("no images here");
      assert.false(onChange.called, "onChange does not fire");
    });
  }
);
