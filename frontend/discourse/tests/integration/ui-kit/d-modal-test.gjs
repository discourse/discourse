import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  click,
  find,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import noop from "discourse/helpers/noop";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubSharedPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

module("Integration | ui-kit | DModal", function (hooks) {
  setupRenderingTest(hooks);

  test("title and subtitle", async function (assert) {
    await render(
      <template>
        <DModal
          @inline={{true}}
          @title="Modal Title"
          @subtitle="Modal Subtitle"
        />
      </template>
    );
    assert.dom(".d-modal .d-modal__title-text").hasText("Modal Title");
    assert.dom(".d-modal .d-modal__subtitle-text").hasText("Modal Subtitle");
  });

  test("named blocks", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}}>
          <:aboveHeader>aboveHeaderContent</:aboveHeader>
          <:headerAboveTitle>headerAboveTitleContent</:headerAboveTitle>
          <:headerBelowTitle>headerBelowTitleContent</:headerBelowTitle>
          <:belowHeader>belowHeaderContent</:belowHeader>
          <:body>bodyContent</:body>
          <:footer>footerContent</:footer>
          <:belowFooter>belowFooterContent</:belowFooter>
        </DModal>
      </template>
    );

    assert.dom(".d-modal").includesText("aboveHeaderContent");
    assert.dom(".d-modal").includesText("headerAboveTitleContent");
    assert.dom(".d-modal").includesText("headerBelowTitleContent");
    assert.dom(".d-modal").includesText("belowHeaderContent");
    assert.dom(".d-modal").includesText("bodyContent");
    assert.dom(".d-modal").includesText("footerContent");
    assert.dom(".d-modal").includesText("belowFooterContent");
  });

  test("headerPrimaryAction block", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}} @title="test">
          <:headerPrimaryAction
          >headerPrimaryActionContent</:headerPrimaryAction>
        </DModal>
      </template>
    );

    assert.dom(".d-modal").doesNotIncludeText("headerPrimaryActionContent");

    await render(
      <template>
        <DModal @inline={{true}} @title="test" @closeModal={{noop}}>
          <:headerPrimaryAction
          >headerPrimaryActionContent</:headerPrimaryAction>
        </DModal>
      </template>
    );

    assert.dom(".d-modal").doesNotIncludeText("headerPrimaryActionContent");

    forceMobile();

    await render(
      <template>
        <DModal @inline={{true}} @title="test" @closeModal={{noop}}>
          <:headerPrimaryAction
          >headerPrimaryActionContent</:headerPrimaryAction>
        </DModal>
      </template>
    );

    assert.dom(".d-modal").includesText("headerPrimaryActionContent");
    assert.dom(".d-modal__dismiss-action-button").exists();

    await render(
      <template>
        <DModal @inline={{true}} @title="test">
          <:headerPrimaryAction
          >headerPrimaryActionContent</:headerPrimaryAction>
        </DModal>
      </template>
    );

    assert.dom(".d-modal__dismiss-action-button").doesNotExist();
  });

  test("flash", async function (assert) {
    await render(
      <template><DModal @inline={{true}} @flash="Some message" /></template>
    );
    assert.dom(".d-modal .alert").hasText("Some message");
  });

  test("flash type", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}} @flash="Some message" @flashType="success" />
      </template>
    );
    assert.dom(".d-modal .alert").hasClass("alert-success");
  });

  test("dismissable", async function (assert) {
    class TestState {
      @tracked dismissable;

      @action
      closeModal() {
        this.closeModalCalled = true;
      }
    }
    const testState = new TestState();
    testState.dismissable = false;

    await render(
      <template>
        <DModal
          @inline={{true}}
          @closeModal={{testState.closeModal}}
          @dismissable={{testState.dismissable}}
        />
      </template>
    );

    assert
      .dom(".d-modal .modal-close")
      .doesNotExist("close button is not shown when dismissable=false");

    testState.dismissable = true;
    await settled();
    assert
      .dom(".d-modal .modal-close")
      .exists("close button is visible when dismissable=true");

    await click(".d-modal .modal-close");
    assert.true(
      testState.closeModalCalled,
      "closeModal is called when close button clicked"
    );
  });

  test("beforeClose can abort closing", async function (assert) {
    let allowClose = false;
    const closeModal = () => assert.step("closeModal");
    const beforeClose = ({ initiatedBy }) => {
      assert.strictEqual(initiatedBy, "initiatedByCloseButton");
      assert.step("beforeClose");
      return allowClose;
    };

    await render(
      <template>
        <DModal
          @inline={{true}}
          @closeModal={{closeModal}}
          @beforeClose={{beforeClose}}
        />
      </template>
    );

    await click(".d-modal .modal-close");
    assert.verifySteps(
      ["beforeClose"],
      "closeModal is not called when beforeClose returns false"
    );

    allowClose = true;
    await click(".d-modal .modal-close");
    assert.verifySteps(
      ["beforeClose", "closeModal"],
      "closeModal is called when beforeClose returns true"
    );
  });

  test("header and body classes", async function (assert) {
    await render(
      <template>
        <DModal
          @inline={{true}}
          @bodyClass="my-body-class"
          @headerClass="my-header-class"
          @title="Hello world"
        />
      </template>
    );

    assert.dom(".d-modal .d-modal__header").hasClass("my-header-class");
    assert.dom(".d-modal .d-modal__body").hasClass("my-body-class");
  });

  test("as a form", async function (assert) {
    let submittedFormData;
    const handleSubmit = (event) => {
      event.preventDefault();
      submittedFormData = new FormData(event.currentTarget);
    };

    await render(
      <template>
        <DModal @inline={{true}} @tagName="form" {{on "submit" handleSubmit}}>
          <:body>
            <input type="text" name="name" value="John Doe" />
          </:body>
          <:footer>
            <button type="submit">Submit</button>
          </:footer>
        </DModal>
      </template>
    );

    assert.dom("form.d-modal").exists();
    await click(".d-modal button[type=submit]");
    assert.deepEqual(submittedFormData.get("name"), "John Doe");
  });

  test("default action on enter", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    // From a text input rather than the body element. The modal autofocuses, so
    // with nothing else focusable the focus would land on the footer button
    // itself, where Enter belongs to that button rather than to the modal.
    await focus(".body-input");
    await triggerKeyEvent(".body-input", "keydown", "Enter");

    assert.true(actionCalled, "pressing enter triggers the default button");
  });

  test("enter with nothing focusable in the body is left to the autofocused button", async function (assert) {
    let calls = 0;
    const someAction = () => {
      calls++;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <p class="body-text">Nothing focusable here.</p>
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    assert
      .dom(document.activeElement)
      .hasClass(
        "btn-primary",
        "with nothing focusable in the body, the modal autofocuses the footer button"
      );

    // Captured on the footer rather than the document: the modal listens on the
    // root in the capture phase, so this runs after it and before the button's
    // own handler, which prevents the default itself.
    let defaultPrevented = null;
    const footer = find(".d-modal__footer");
    const observe = (event) => {
      defaultPrevented = event.defaultPrevented;
    };
    footer.addEventListener("keydown", observe, { capture: true });
    try {
      await triggerKeyEvent(".btn-primary", "keydown", "Enter");
    } finally {
      footer.removeEventListener("keydown", observe, { capture: true });
    }

    // The focused button acts on Enter itself. The modal clicking it as well
    // would run the action twice, and swallowing the key would stop it running
    // at all.
    assert.strictEqual(
      calls,
      1,
      "the focused button runs its action exactly once"
    );
    assert.false(
      defaultPrevented,
      "and the modal leaves the key alone rather than claiming it"
    );
  });

  test("enter on a focused button triggers that button, not the default action", async function (assert) {
    const calls = [];
    const onBody = () => calls.push("body");
    const onFooter = () => calls.push("footer");

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <DButton
              @action={{onBody}}
              @translatedLabel="Body action"
              class="body-button"
            />
          </:body>
          <:footer>
            <DButton
              @action={{onFooter}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-button");
    await triggerKeyEvent(".body-button", "keydown", "Enter");

    // The modal listens on the document in the capture phase, so it sees Enter
    // before the button does. Without an exemption it submits the modal out from
    // under any body control a keyboard user is standing on.
    assert.deepEqual(
      calls,
      ["body"],
      "the focused button runs its own action and the modal is not submitted"
    );
  });

  test("enter on a focused link is left to the link", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>

            <a class="body-link" href="#somewhere">A link</a>
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-link");
    await triggerKeyEvent(".body-link", "keydown", "Enter");

    assert.false(
      actionCalled,
      "the link is what the user is standing on, so the modal is not submitted out from under it"
    );
  });

  test("enter with no primary button is left to the browser", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <DButton @translatedLabel="Not primary" class="btn-danger" />
          </:footer>
        </DModal>
      </template>
    );

    let defaultPrevented = null;
    const bodyInput = find(".body-input");
    const observe = (event) => {
      defaultPrevented = event.defaultPrevented;
    };
    bodyInput.addEventListener("keydown", observe);
    try {
      await focus(".body-input");
      await triggerKeyEvent(".body-input", "keydown", "Enter");
    } finally {
      bodyInput.removeEventListener("keydown", observe);
    }

    assert.false(
      defaultPrevented,
      "with nothing to submit, the key is left alone rather than swallowed"
    );
  });

  test("enter does not fall through a disabled primary to the next one", async function (assert) {
    const calls = [];
    const onUpload = () => calls.push("upload");
    const onClose = () => calls.push("close");

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <DButton
              @action={{onUpload}}
              @translatedLabel="Upload"
              @disabled={{true}}
              class="btn-primary"
            />
            <DButton
              @action={{onClose}}
              @translatedLabel="Close"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-input");
    await triggerKeyEvent(".body-input", "keydown", "Enter");

    // The first primary is the modal's primary action whether or not it can act.
    // Skipping past it lands the press on a different button entirely, which in
    // a real footer is the one that closes the modal.
    assert.deepEqual(
      calls,
      [],
      "a disabled primary means nothing to submit, not submit the next thing along"
    );
  });

  test("enter is not claimed for a primary disabled by an ancestor fieldset", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <fieldset disabled>
              <DButton @translatedLabel="Perform action" class="btn-primary" />
            </fieldset>
          </:footer>
        </DModal>
      </template>
    );

    let defaultPrevented = null;
    const bodyInput = find(".body-input");
    const observe = (event) => {
      defaultPrevented = event.defaultPrevented;
    };
    bodyInput.addEventListener("keydown", observe);
    try {
      await focus(".body-input");
      await triggerKeyEvent(".body-input", "keydown", "Enter");
    } finally {
      bodyInput.removeEventListener("keydown", observe);
    }

    // Asserted on the key rather than the action: the browser suppresses a click
    // on a fieldset-disabled control anyway, so whether the action ran says
    // nothing about whether the modal thought it had something to submit.
    // Claiming the key is the part that is actually the modal's doing.
    assert.false(
      defaultPrevented,
      "a control inside a disabled fieldset carries no attribute of its own, and is still nothing to submit"
    );
  });

  test("enter does not run a disabled primary rendered as a link", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              @href="/somewhere"
              @disabled={{true}}
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-input");
    await triggerKeyEvent(".body-input", "keydown", "Enter");

    // An anchor is not a form control, so it never matches `:disabled` however
    // it was marked. The attribute is what is actually there.
    assert.false(
      actionCalled,
      "a primary marked unavailable is not clicked, whichever tag it renders as"
    );
  });

  test("enter on a focused select still submits the modal", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>

            <select class="body-select">
              <option value="a">A</option>
            </select>
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-select");
    await triggerKeyEvent(".body-select", "keydown", "Enter");

    // A select does nothing with Enter of its own outside a form, so exempting
    // it would take the key from the modal and hand it to nothing.
    assert.true(
      actionCalled,
      "the modal keeps the key, because the select has no use for it"
    );
  });

  test("enter on a focused file input is left to the file input", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-file" type="file" />
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Upload"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await focus(".body-file");
    await triggerKeyEvent(".body-file", "keydown", "Enter");

    // Enter on a file input opens its picker, so the modal must not take the key
    // and submit instead.
    assert.false(
      actionCalled,
      "the file input keeps the key rather than the modal submitting under it"
    );
  });

  test("enter with a primary that cannot be clicked is left to the browser", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <input class="body-input" type="text" />
          </:body>
          <:footer>
            <DButton
              @translatedLabel="Upload"
              @disabled={{true}}
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    let defaultPrevented = null;
    const bodyInput = find(".body-input");
    const observe = (event) => {
      defaultPrevented = event.defaultPrevented;
    };
    bodyInput.addEventListener("keydown", observe);
    try {
      await focus(".body-input");
      await triggerKeyEvent(".body-input", "keydown", "Enter");
    } finally {
      bodyInput.removeEventListener("keydown", observe);
    }

    // Clicking a disabled primary does nothing, so claiming the key for it
    // spends the press on nothing at all.
    assert.false(
      defaultPrevented,
      "a primary that cannot act is not something to claim the key for"
    );
  });

  test("enter inside select-kit does not trigger default action", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DModal @inline={{true}}>
          <:body>
            <div class="select-kit">
              <input class="filter-input" type="text" />
            </div>
          </:body>
          <:footer>
            <DButton
              @action={{someAction}}
              @translatedLabel="Perform action"
              class="btn-primary"
            />
          </:footer>
        </DModal>
      </template>
    );

    await triggerKeyEvent(".filter-input", "keydown", "Enter");

    assert.false(
      actionCalled,
      "pressing enter inside select-kit does not trigger the default button"
    );
  });

  test("does not swallow keystrokes aimed at a modal stacked above it", async function (assert) {
    await render(
      <template>
        <DModal @inline={{true}} @title="Underlying modal" />
        <DModal @inline={{true}} @title="Stacked modal">
          <:body>
            <input type="text" class="stacked-modal-input" />
          </:body>
        </DModal>
      </template>
    );

    const inputElement = document.querySelector(".stacked-modal-input");
    inputElement.focus();

    const event = new KeyboardEvent("keydown", {
      key: "a",
      bubbles: true,
      cancelable: true,
    });
    inputElement.dispatchEvent(event);

    assert.false(
      event.defaultPrevented,
      "the underlying modal does not preventDefault keystrokes aimed at the modal stacked above it"
    );
  });

  module("mobile swipe dismissal", function (innerHooks) {
    innerHooks.beforeEach(function () {
      forceMobile();
    });

    // `timeStamp` is a prototype accessor an own property shadows; the real
    // spacing of synthetic events reads as a flick to the velocity rule
    function dispatchPointer(type, { y, time }) {
      const event = new PointerEvent(type, {
        bubbles: true,
        cancelable: true,
        button: 0,
        pointerId: 1,
        clientY: y,
      });
      Object.defineProperty(event, "timeStamp", { value: time });
      find(".d-modal__container").dispatchEvent(event);
    }

    async function dragContainer({ by, overMs = 400 }) {
      stubSharedPointerCapture([".d-modal__container"]);
      dispatchPointer("pointerdown", { y: 100, time: 1000 });
      dispatchPointer("pointermove", { y: 100 + by, time: 1000 + overMs });
      dispatchPointer("pointerup", { y: 100 + by, time: 1000 + overMs + 16 });
      await settled();
    }

    test("dragging down far enough closes the modal", async function (assert) {
      const closeModal = () => assert.step("closeModal");
      await render(
        <template>
          <DModal @inline={{true}} @closeModal={{closeModal}} />
        </template>
      );

      const distance = find(".d-modal__container").clientHeight * 0.25 + 10;
      await dragContainer({ by: distance });

      assert.verifySteps(["closeModal"], "past a quarter height it dismisses");
    });

    test("a short drag settles the modal back", async function (assert) {
      const closeModal = () => assert.step("closeModal");
      await render(
        <template>
          <DModal @inline={{true}} @closeModal={{closeModal}} />
        </template>
      );

      await dragContainer({ by: 10 });

      assert.verifySteps([], "a short slow drag does not dismiss");
      const { transform } = window.getComputedStyle(
        find(".d-modal__container")
      );
      assert.strictEqual(
        transform === "none" ? 0 : new DOMMatrixReadOnly(transform).m42,
        0,
        "and it settles back to resting position"
      );
    });

    test("a press on a control hands it the pointer capture", async function (assert) {
      await render(
        <template>
          <DModal @inline={{true}} @title="test" @closeModal={{noop}} />
        </template>
      );

      const { ownerOf } = stubSharedPointerCapture([
        ".d-modal__container",
        ".modal-close",
      ]);
      await triggerEvent(".modal-close", "pointerdown", {
        button: 0,
        pointerId: 2,
      });

      assert
        .dom(ownerOf(2))
        .hasClass("modal-close", "a tap's click reaches the control");

      await triggerEvent(".modal-close", "pointerup", { pointerId: 2 });
    });
  });
});
