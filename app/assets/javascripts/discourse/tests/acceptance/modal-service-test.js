import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import { setComponentTemplate } from "@glimmer/manager";

class MyModalClass extends Component {}
setComponentTemplate(
  hbs`
    <DModal
      @closeModal={{@closeModal}}
      @title="Hello World"
    >
      Modal content is {{@model.text}}
    </DModal>
  `,
  MyModalClass
);

acceptance("Modal service: component-based API", function () {
  test("displays correctly", async function (assert) {
    await visit("/");

    assert.dom(".d-modal").doesNotExist("there is no modal at first");

    const modalService = getOwner(this).lookup("service:modal");

    modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal should appear");

    assert.dom(".d-modal .title h3").hasText("Hello World");
    assert.dom(".d-modal .modal-body").hasText("Modal content is working");

    await click(".modal-outer-container");
    assert.dom(".d-modal").doesNotExist("disappears on click outside");

    modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    await triggerKeyEvent("#main-outlet", "keydown", "Escape");
    assert.dom(".d-modal").doesNotExist("disappears on escape");

    modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    await click(".d-modal .modal-close");
    assert.dom(".d-modal").doesNotExist("disappears when close button clicked");
  });

  // (See also, `tests/integration/component/d-modal-test.js`)
});
