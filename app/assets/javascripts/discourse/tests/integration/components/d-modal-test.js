import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | d-modal", function (hooks) {
  setupRenderingTest(hooks);

  test("title and subtitle", async function (assert) {
    await render(
      hbs`<DModal @inline={{true}} @title="Modal Title" @subtitle="Modal Subtitle" />`
    );
    assert.dom(".d-modal .title h3").hasText("Modal Title");
    assert.dom(".d-modal .subtitle").hasText("Modal Subtitle");
  });

  test("named blocks", async function (assert) {
    await render(
      hbs`
        <DModal @inline={{true}}>
          <:aboveHeader>aboveHeaderContent</:aboveHeader>
          <:headerAboveTitle>headerAboveTitleContent</:headerAboveTitle>
          <:headerBelowTitle>headerBelowTitleContent</:headerBelowTitle>
          <:belowHeader>belowHeaderContent</:belowHeader>
          <:body>bodyContent</:body>
          <:footer>footerContent</:footer>
          <:belowFooter>belowFooterContent</:belowFooter>
        </DModal>
      `
    );

    assert.dom(".d-modal").includesText("aboveHeaderContent");
    assert.dom(".d-modal").includesText("headerAboveTitleContent");
    assert.dom(".d-modal").includesText("headerBelowTitleContent");
    assert.dom(".d-modal").includesText("belowHeaderContent");
    assert.dom(".d-modal").includesText("bodyContent");
    assert.dom(".d-modal").includesText("footerContent");
    assert.dom(".d-modal").includesText("belowFooterContent");
  });

  test("flash", async function (assert) {
    await render(hbs`<DModal @inline={{true}} @flash="Some message"/>`);
    assert.dom(".d-modal .alert").hasText("Some message");
  });

  test("flash type", async function (assert) {
    await render(
      hbs`<DModal @inline={{true}} @flash="Some message" @flashType="success"/>`
    );
    assert.dom(".d-modal .alert").hasClass("alert-success");
  });

  test("dismissable", async function (assert) {
    let closeModalCalled = false;
    this.closeModal = () => (closeModalCalled = true);
    this.set("dismissable", false);

    await render(
      hbs`<DModal @inline={{true}} @closeModal={{this.closeModal}} @dismissable={{this.dismissable}}/>`
    );

    assert
      .dom(".d-modal .modal-close")
      .doesNotExist("close button is not shown when dismissable=false");

    this.set("dismissable", true);
    await settled();
    assert
      .dom(".d-modal .modal-close")
      .exists("close button is visible when dismissable=true");

    await click(".d-modal .modal-close");
    assert.true(
      closeModalCalled,
      "closeModal is called when close button clicked"
    );

    closeModalCalled = false;
  });

  test("header and body classes", async function (assert) {
    await render(
      hbs`<DModal @inline={{true}} @bodyClass="my-body-class" @headerClass="my-header-class" @title="Hello world" />`
    );

    assert.dom(".d-modal .modal-header").hasClass("my-header-class");
    assert.dom(".d-modal .modal-body").hasClass("my-body-class");
  });

  test("as a form", async function (assert) {
    let submittedFormData;
    this.handleSubmit = (event) => {
      event.preventDefault();
      submittedFormData = new FormData(event.currentTarget);
    };

    await render(
      hbs`
        <DModal @inline={{true}} @tagName="form" {{on "submit" this.handleSubmit}}>
          <:body>
            <input type="text" name="name" value="John Doe" />
          </:body>
          <:footer>
            <button type="submit">Submit</button>
          </:footer>
        </DModal>
        `
    );

    assert.dom("form.d-modal").exists();
    await click(".d-modal button[type=submit]");
    assert.deepEqual(submittedFormData.get("name"), "John Doe");
  });
});
