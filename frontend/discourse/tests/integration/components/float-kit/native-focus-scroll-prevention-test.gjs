import { tracked } from "@glimmer/tracking";
import { clearRender, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  isInsidePreventionContainer,
  isNearViewportBottom,
  isPasswordRelatedInput,
} from "discourse/float-kit/components/d-scroll/focus-scroll-utils";
import isTextInput from "discourse/float-kit/components/d-scroll/is-text-input";
import nativeFocusScrollPrevention from "discourse/float-kit/components/d-scroll/native-focus-scroll-prevention";
import { isCloneElement } from "discourse/float-kit/lib/utils";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const CLONE_SELECTOR = "[data-d-scroll-clone='true']";

function invokeQualifyingBlur(assert, context, source, relatedTarget) {
  const viewportBottom = window.visualViewport?.height ?? 0;

  source.getBoundingClientRect = () => ({
    bottom: viewportBottom,
    height: 40,
  });

  assert.true(
    isInsidePreventionContainer(relatedTarget),
    "the target is inside an enabled prevention container"
  );
  assert.true(isTextInput(source), "the blurred element is a text input");
  assert.true(isTextInput(relatedTarget), "the target is a text input");
  assert.false(
    isPasswordRelatedInput(relatedTarget),
    "the target is not password related"
  );
  assert.false(isCloneElement(source), "the blurred element is not a clone");
  assert.true(
    isNearViewportBottom(source),
    "the blurred element is near the visual viewport bottom"
  );

  const listenerCalls = context.addDocumentListener.getCalls();
  let listenerCall;

  for (let index = listenerCalls.length - 1; index >= 0; index--) {
    const candidate = listenerCalls[index];
    if (
      candidate.args[0] === "blur" &&
      candidate.args[2]?.capture === true &&
      candidate.args[2]?.passive === false
    ) {
      listenerCall = candidate;
      break;
    }
  }

  if (!listenerCall) {
    throw new Error("The native focus blur listener was not registered");
  }

  const blurListener = listenerCall.args[1];
  assert.strictEqual(
    blurListener.name,
    "handleBlur",
    "the native non-passive blur handler is selected"
  );
  assert.deepEqual(
    listenerCall.args[2],
    { capture: true, passive: false },
    "the selected listener uses Silk's blur options"
  );

  blurListener({ target: source, relatedTarget });
  return blurListener;
}

module(
  "Integration | Component | FloatKit | native focus scroll prevention",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      sinon.stub(capabilities, "isWebKit").value(true);
      sinon.stub(capabilities, "isAppleMobile").value(true);
      this.addDocumentListener = sinon.spy(document, "addEventListener");
      this.removeDocumentListener = sinon.spy(document, "removeEventListener");
    });

    hooks.afterEach(async function () {
      await clearRender();
      this.clock?.restore();
      sinon.restore();
    });

    test("destroying one preventer cancels only its pending focus job", async function (assert) {
      const state = new (class {
        @tracked showFirst = true;
      })();

      await render(
        <template>
          {{#if state.showFirst}}
            <div
              class="first-container"
              data-d-scroll="scroll-container"
              {{nativeFocusScrollPrevention true}}
            >
              <input class="first-source" />
              <textarea class="first-target"></textarea>
            </div>
          {{/if}}
          <div
            class="second-container"
            data-d-scroll="scroll-container"
            {{nativeFocusScrollPrevention true}}
          >
            <input class="second-source" />
            <textarea class="second-target"></textarea>
          </div>
        </template>
      );

      this.clock = sinon.useFakeTimers({
        toFake: ["setTimeout", "clearTimeout"],
      });
      const firstTarget = find(".first-target");
      const focusFirstTarget = sinon.spy(firstTarget, "focus");

      assert
        .dom(".first-container")
        .hasAttribute("data-d-scroll-focus-prevention", "true");
      const blurListener = invokeQualifyingBlur(
        assert,
        this,
        find(".first-source"),
        firstTarget
      );
      assert.notStrictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "a clone is pending"
      );

      state.showFirst = false;
      await settled();

      assert.strictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "destroying the owner removes its clone immediately"
      );

      this.clock.tick(32);
      assert.false(
        focusFirstTarget.called,
        "the destroyed owner's target is not refocused"
      );
      assert.false(
        this.removeDocumentListener.calledWith("blur", blurListener),
        "the remaining preventer retains the global blur listener"
      );

      const secondTarget = find(".second-target");
      const focusSecondTarget = sinon.spy(secondTarget, "focus");
      invokeQualifyingBlur(assert, this, find(".second-source"), secondTarget);

      assert.notStrictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "the remaining preventer retains the global listeners"
      );

      this.clock.tick(32);
      assert.true(
        focusSecondTarget.calledOnce,
        "the remaining preventer's focus job still completes"
      );
    });

    test("disabling prevention cancels its pending focus job", async function (assert) {
      const state = new (class {
        @tracked enabled = true;
      })();

      await render(
        <template>
          <div
            class="focus-container"
            data-d-scroll="scroll-container"
            {{nativeFocusScrollPrevention state.enabled}}
          >
            <input class="source" />
            <textarea class="target"></textarea>
          </div>
        </template>
      );

      this.clock = sinon.useFakeTimers({
        toFake: ["setTimeout", "clearTimeout"],
      });
      const target = find(".target");
      const focusTarget = sinon.spy(target, "focus");

      assert
        .dom(".focus-container")
        .hasAttribute("data-d-scroll-focus-prevention", "true");
      const blurListener = invokeQualifyingBlur(
        assert,
        this,
        find(".source"),
        target
      );
      assert.notStrictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "a clone is pending"
      );

      state.enabled = false;
      await settled();

      assert.strictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "disabling prevention removes its clone immediately"
      );

      this.clock.tick(32);
      assert.false(
        focusTarget.called,
        "disabled prevention cannot reclaim focus"
      );
      assert.true(
        this.removeDocumentListener.calledWith("blur", blurListener),
        "the last preventer unregisters the global blur listener"
      );
    });

    test("a pending target must remain in the same enabled owner", async function (assert) {
      await render(
        <template>
          <div
            class="first-container"
            data-d-scroll="scroll-container"
            {{nativeFocusScrollPrevention true}}
          >
            <input class="source" />
            <textarea class="target"></textarea>
          </div>
          <div
            class="second-container"
            data-d-scroll="scroll-container"
            {{nativeFocusScrollPrevention true}}
          ></div>
        </template>
      );

      this.clock = sinon.useFakeTimers({
        toFake: ["setTimeout", "clearTimeout"],
      });
      const target = find(".target");
      const focusTarget = sinon.spy(target, "focus");

      assert
        .dom(".first-container")
        .hasAttribute("data-d-scroll-focus-prevention", "true");
      invokeQualifyingBlur(assert, this, find(".source"), target);
      find(".second-container").append(target);
      this.clock.tick(32);

      assert.false(
        focusTarget.called,
        "a connected target moved to another preventer is not refocused"
      );
      assert.strictEqual(
        document.querySelector(CLONE_SELECTOR),
        null,
        "the stale clone is still removed"
      );
    });

    test("a newer focus job replaces the pending job for its owner", async function (assert) {
      await render(
        <template>
          <div
            data-d-scroll="scroll-container"
            {{nativeFocusScrollPrevention true}}
          >
            <input class="first-source" />
            <textarea class="first-target"></textarea>
            <input class="second-source" />
            <textarea class="second-target"></textarea>
          </div>
        </template>
      );

      this.clock = sinon.useFakeTimers({
        toFake: ["setTimeout", "clearTimeout"],
      });
      const firstTarget = find(".first-target");
      const secondTarget = find(".second-target");
      const focusFirstTarget = sinon.spy(firstTarget, "focus");
      const focusSecondTarget = sinon.spy(secondTarget, "focus");

      assert
        .dom("[data-d-scroll~='scroll-container']")
        .hasAttribute("data-d-scroll-focus-prevention", "true");
      invokeQualifyingBlur(assert, this, find(".first-source"), firstTarget);
      const firstClone = document.querySelector(CLONE_SELECTOR);
      invokeQualifyingBlur(assert, this, find(".second-source"), secondTarget);

      assert.false(firstClone.isConnected, "the superseded clone is removed");
      assert.strictEqual(
        document.querySelectorAll(CLONE_SELECTOR).length,
        1,
        "only the newest clone remains"
      );

      this.clock.tick(32);

      assert.false(
        focusFirstTarget.called,
        "the superseded target is not refocused"
      );
      assert.true(
        focusSecondTarget.calledOnce,
        "the newest target receives focus"
      );
    });
  }
);
