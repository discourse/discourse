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
    await render(
      hbs`<DModal @inline={{true}} @flash="Some message" @flashType="error"/> `
    );
    assert.dom(".d-modal .alert.alert-error").hasText("Some message");
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
});
