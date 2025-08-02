import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DModal, {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
  CLOSE_INITIATED_BY_ESC,
  CLOSE_INITIATED_BY_MODAL_SHOW,
} from "discourse/components/d-modal";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";

class MyModalClass extends Component {
  <template>
    <DModal
      class="service-modal"
      @closeModal={{@closeModal}}
      @title="Hello World"
    >
      Modal content is
      {{@model.text}}
      <button
        type="button"
        class="custom-data"
        {{on "click" this.closeWithCustomData}}
      ></button>
    </DModal>
  </template>

  @action
  closeWithCustomData() {
    this.args.closeModal({ hello: "world" });
  }
}

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

    assert.dom(".d-modal__title-text").hasText("Hello World");
    assert.dom(".d-modal .d-modal__body").hasText("Modal content is working");

    await click(".d-modal__backdrop");
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
      .dom(".d-modal .d-modal__body")
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

  test("alongside declarative modals", async function (assert) {
    class State {
      @tracked showDeclarativeModal;
    }

    const testState = new State();
    const closeModal = () => (testState.showDeclarativeModal = false);

    const MyConnector = <template>
      {{#if testState.showDeclarativeModal}}
        <DModal
          class="declarative-modal"
          @title="Declarative modal"
          @closeModal={{closeModal}}
        >
          <span class="declarative-modal-content">Declarative modal content</span>
        </DModal>
      {{/if}}
    </template>;

    registerTemporaryModule(
      "discourse/plugins/my-plugin/connectors/below-footer/connector-name",
      MyConnector
    );

    await visit("/");

    const modalService = getOwner(this).lookup("service:modal");

    modalService.show(MyModalClass);
    await settled();
    assert.dom(".d-modal.service-modal").exists("modal should appear");

    testState.showDeclarativeModal = true;
    await settled();
    assert
      .dom(".d-modal.declarative-modal")
      .exists("declarative modal should appear");
    assert.dom(".d-modal.service-modal").exists("service modal should remain");

    await click(".d-modal.declarative-modal .modal-close");
    assert
      .dom(".d-modal.declarative-modal")
      .doesNotExist("declarative modal should close");
    assert.dom(".d-modal.service-modal").exists("service modal should remain");

    await click(".d-modal.service-modal .modal-close");
    assert.dom(".d-modal").doesNotExist("all modals closed");
  });

  // (See also, `tests/integration/component/d-modal-test.js`)
});
