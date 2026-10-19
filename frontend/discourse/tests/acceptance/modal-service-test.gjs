import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";
import DModal, {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
  CLOSE_INITIATED_BY_ESC,
  CLOSE_INITIATED_BY_MODAL_SHOW,
} from "discourse/ui-kit/d-modal";

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
        class="custom-data"
        type="button"
        {{on "click" this.closeWithCustomData}}
      ></button>
    </DModal>
  </template>

  @action
  closeWithCustomData() {
    this.args.closeModal({ hello: "world" });
  }
}

function resolvedSoon(promise) {
  return Promise.race([
    promise,
    new Promise((resolve) => setTimeout(() => resolve("still pending"), 100)),
  ]);
}

acceptance("Modal service: component-based API", function () {
  test("loads a core modal when requested and resolves its close data", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");

    const promise = modalService.show(
      import("discourse/components/modal/post-enqueued"),
      {
        model: { pending_count: 2 },
      }
    );
    await settled();

    assert.dom(".post-enqueued-modal").exists("the requested modal renders");
    await click(".post-enqueued-modal .modal-close");
    assert.deepEqual(
      await promise,
      { initiatedBy: CLOSE_INITIATED_BY_BUTTON },
      "the lazy modal returns its close data"
    );
  });

  test("closing during a load resolves right away and the modal never opens", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    let finishLoading;
    const loading = new Promise((resolve) => (finishLoading = resolve));
    const promise = modalService.show(loading);

    modalService.close({ cancelled: true });

    assert.deepEqual(await resolvedSoon(promise), { cancelled: true });

    finishLoading(await import("discourse/components/modal/post-enqueued"));
    await settled();
    assert.dom(".d-modal").doesNotExist("the cancelled load never opens");
  });

  test("overrides receive the import promise, then the loaded class", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    const show = sinon.spy(modalService, "show");

    try {
      modalService.show(import("discourse/components/modal/post-enqueued"), {
        model: { pending_count: 2 },
      });
      await settled();
      const { default: PostEnqueued } =
        await import("discourse/components/modal/post-enqueued");

      assert.true(show.firstCall.args[0] instanceof Promise);
      assert.strictEqual(show.secondCall.args[0], PostEnqueued);
    } finally {
      show.restore();
    }
  });

  test("the current modal stays open until the requested one loads", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    let finishLoading;
    const loading = new Promise((resolve) => (finishLoading = resolve));

    const current = modalService.show(MyModalClass, {
      model: { text: "current" },
    });
    await settled();
    modalService.show(loading);
    await Promise.resolve();

    assert.dom(".service-modal").exists("the current modal is still open");

    finishLoading(await import("discourse/components/modal/post-enqueued"));
    await settled();

    assert.deepEqual(await current, {
      initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW,
    });
    assert.dom(".service-modal").doesNotExist();
    assert.dom(".post-enqueued-modal").exists("the loaded modal replaces it");
  });

  test("a newer modal supersedes an earlier load", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    let finishLoading;
    const loading = new Promise((resolve) => (finishLoading = resolve));
    const pending = modalService.show(loading);

    modalService.show(MyModalClass, { model: { text: "latest" } });

    assert.deepEqual(await resolvedSoon(pending), {
      initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW,
    });

    finishLoading(await import("discourse/components/modal/post-enqueued"));
    await settled();
    assert.dom(".service-modal").exists("the latest request opens");
    assert
      .dom(".post-enqueued-modal")
      .doesNotExist("the stale request stays closed");
  });

  test("a failed load does not prevent later modals", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");

    await assert.rejects(
      modalService.show(Promise.reject(new Error("Modal download failed"))),
      /Modal download failed/,
      "the load failure is reported to the caller"
    );

    modalService.show(MyModalClass, { model: { text: "recovered" } });
    await settled();
    assert.dom(".service-modal").exists("a later modal opens normally");
  });

  test("a lazy modal restores focus to its original trigger", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    await click(".header-sidebar-toggle button");
    const trigger = document.activeElement;

    modalService.show(import("discourse/components/modal/post-enqueued"));
    await settled();
    await click(".post-enqueued-modal .modal-close");

    assert.strictEqual(
      document.activeElement,
      trigger,
      "focus returns to the trigger"
    );
  });

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
    const showDeclarativeModal = tracked(undefined);
    const closeModal = () => (showDeclarativeModal.value = false);

    const MyConnector = <template>
      {{#if showDeclarativeModal.value}}
        <DModal
          class="declarative-modal"
          @closeModal={{closeModal}}
          @title="Declarative modal"
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

    showDeclarativeModal.value = true;
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

  test("refocuses trigger element on close", async function (assert) {
    await visit("/");

    const modalService = getOwner(this).lookup("service:modal");

    await click(".header-sidebar-toggle button");
    const triggerElement = document.activeElement;

    modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists();

    await click(".d-modal .modal-close");
    assert.dom(".d-modal").doesNotExist();
    assert.strictEqual(
      document.activeElement,
      triggerElement,
      "focus returns to trigger element"
    );
  });

  test("does not error when trigger element is removed from DOM", async function (assert) {
    await visit("/");

    const modalService = getOwner(this).lookup("service:modal");

    const button = document.createElement("button");
    button.className = "temporary-trigger";
    document.body.appendChild(button);
    button.focus();

    modalService.show(MyModalClass, { model: { text: "working" } });
    await settled();
    assert.dom(".d-modal").exists();

    button.remove();

    await click(".d-modal .modal-close");
    assert.dom(".d-modal").doesNotExist();
  });

  // (See also, `tests/integration/component/d-modal-test.js`)
});

acceptance("Modal service: mobile keyboard", function (needs) {
  needs.mobileView();

  test("closing while the keyboard is visible cancels the pending modal", async function (assert) {
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");

    document.documentElement.classList.add("keyboard-visible");
    try {
      const promise = modalService.show(MyModalClass, {
        model: { text: "cancelled" },
      });

      modalService.close({ cancelled: true });

      assert.deepEqual(
        await promise,
        { cancelled: true },
        "closing resolves the request before the keyboard closes"
      );

      document.documentElement.classList.remove("keyboard-visible");
      await settled();

      assert
        .dom(".service-modal")
        .doesNotExist(
          "the cancelled modal stays closed after the keyboard closes"
        );
    } finally {
      document.documentElement.classList.remove("keyboard-visible");
    }
  });
});
