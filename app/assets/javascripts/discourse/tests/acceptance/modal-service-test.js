import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import { setComponentTemplate } from "@glimmer/manager";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
  CLOSE_INITIATED_BY_ESC,
  CLOSE_INITIATED_BY_MODAL_SHOW,
} from "discourse/components/d-modal";
import { action } from "@ember/object";

class MyModalClass extends Component {
  @action
  closeWithCustomData() {
    this.args.closeModal({ hello: "world" });
  }
}
setComponentTemplate(
  hbs`
    <DModal
      @closeModal={{@closeModal}}
      @title="Hello World"
    >
      Modal content is {{@model.text}}
      <button class='custom-data' {{on "click" this.closeWithCustomData}}></button>
    </DModal>
  `,
  MyModalClass
);

acceptance("Modal service: component-based API", function () {
  test("displays correctly", async function (assert) {
    await visit("/");

    assert.dom(".d-modal").doesNotExist("there is no modal at first");

    const modalService = getOwner(this).lookup("service:modal");

    let promise = modalService.show(MyModalClass, {
      model: { text: "working" },
    });
    await settled();
    assert.dom(".d-modal").exists("modal should appear");

    assert.dom(".d-modal .title h3").hasText("Hello World");
    assert.dom(".d-modal .modal-body").hasText("Modal content is working");

    await click(".modal-outer-container");
    assert.dom(".d-modal").doesNotExist("disappears on click outside");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_CLICK_OUTSIDE },
      "promise resolves with correct initiator"
    );

    promise = modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    await triggerKeyEvent("#main-outlet", "keydown", "Escape");
    assert.dom(".d-modal").doesNotExist("disappears on escape");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_ESC },
      "promise resolves with correct initiator"
    );

    promise = modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    await click(".d-modal .modal-close");
    assert.dom(".d-modal").doesNotExist("disappears when close button clicked");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_BUTTON },
      "promise resolves with correct initiator"
    );

    promise = modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    await click(".d-modal .modal-close");
    assert.dom(".d-modal").doesNotExist("disappears when close button clicked");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_BUTTON },
      "promise resolves with correct initiator"
    );

    promise = modalService.show(MyModalClass, { model: { text: "first" } });
    await settled();
    assert.dom(".d-modal").exists("modal reappears");

    modalService.show(MyModalClass, { model: { text: "second" } });
    await settled();
    assert
      .dom(".d-modal .modal-body")
      .hasText("Modal content is second", "new modal replaces old");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW },
      "first modal promise resolves with correct initiator"
    );
  });

  test("lifecycle hooks and arguments", async function (assert) {
    await visit("/");

    const events = [];

    class ModalWithLifecycleHooks extends MyModalClass {
      constructor() {
        super(...arguments);
        events.push(`constructor: ${this.args.model?.data}`);
      }

      willDestroy() {
        events.push(`willDestroy: ${this.args.model?.data}`);
      }
    }

    const modalService = getOwner(this).lookup("service:modal");

    modalService.show(ModalWithLifecycleHooks, {
      model: { data: "argumentValue" },
    });
    await settled();

    assert.deepEqual(
      events,
      ["constructor: argumentValue"],
      "constructor called with args available"
    );

    modalService.close();
    await settled();

    assert.deepEqual(
      events,
      ["constructor: argumentValue", "willDestroy: argumentValue"],
      "constructor called with args available"
    );
  });

  // (See also, `tests/integration/component/d-modal-test.js`)
});
