import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { render, settled, triggerEvent, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import FormComposer from "discourse/components/form-template-field/composer";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function fakeUppy() {
  return {
    setup: sinon.spy(),
    teardown: sinon.spy(),
    textManipulation: null,
  };
}

module(
  "Integration | Component | form-template-field | composer",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      sinon.restore();
    });

    function stubAllowUpload(context, value) {
      const composerService = getOwner(context).lookup("service:composer");
      sinon.stub(composerService, "allowUpload").value(value);
    }

    test("renders a composer with no uppy plumbing when none provided", async function (assert) {
      stubAllowUpload(this, true);

      await render(<template><FormComposer @onChange={{noop}} /></template>);

      assert
        .dom("[data-field-type='composer'] .d-editor-input")
        .exists("the markdown editor renders");
    });

    test("wires uploads onto the editor when uppyComposerUpload is provided", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      // setup() is called from DEditor's onSetup, which fires after the inner
      // editor mounts asynchronously.
      await waitUntil(() => uppy.setup.called);

      assert.strictEqual(uppy.setup.callCount, 1, "setup is called once");
      assert.true(
        uppy.setup.firstCall.firstArg.classList.contains("d-editor"),
        "setup receives the .d-editor wrapper element"
      );
      assert.true(
        uppy.textManipulation?.textarea instanceof HTMLTextAreaElement,
        "textManipulation is set so the upload pipeline can insert markdown"
      );
    });

    test("skips wiring when allowUpload is false", async function (assert) {
      stubAllowUpload(this, false);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      assert.false(uppy.setup.called, "setup is not called");
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

      await waitUntil(() => uppy.setup.called);

      const initialTextManipulation = uppy.textManipulation;
      uppy.textManipulation = "trampled-by-another-field";

      await triggerEvent(".d-editor-input", "focusin");

      assert.strictEqual(
        uppy.textManipulation,
        initialTextManipulation,
        "focusin restores this field's textManipulation as the upload target"
      );
    });

    test("calls teardown when the field is destroyed", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      const state = new (class {
        @tracked show = true;
      })();
      this.set("uppy", uppy);
      this.set("state", state);

      await render(
        <template>
          {{#if this.state.show}}
            <FormComposer
              @onChange={{noop}}
              @uppyComposerUpload={{this.uppy}}
            />
          {{/if}}
        </template>
      );

      await waitUntil(() => uppy.setup.called);
      const setupElement = uppy.setup.firstCall.firstArg;

      state.show = false;
      await settled();

      assert.true(uppy.teardown.called, "teardown runs on destroy");
      assert.strictEqual(
        uppy.teardown.firstCall.firstArg,
        setupElement,
        "teardown receives the same element setup was called with"
      );
    });

    test("multiple fields each set up the shared uppy and route on focus", async function (assert) {
      stubAllowUpload(this, true);

      const uppy = fakeUppy();
      this.set("uppy", uppy);

      await render(
        <template>
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
          <FormComposer @onChange={{noop}} @uppyComposerUpload={{this.uppy}} />
        </template>
      );

      await waitUntil(() => uppy.setup.callCount === 2);

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
  }
);
