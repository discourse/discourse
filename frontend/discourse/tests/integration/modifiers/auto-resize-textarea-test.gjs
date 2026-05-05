import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import autoResizeTextarea from "discourse/modifiers/auto-resize-textarea";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

async function withScrollHeight(scrollHeight, callback) {
  const descriptor = Object.getOwnPropertyDescriptor(
    HTMLTextAreaElement.prototype,
    "scrollHeight"
  );

  Object.defineProperty(HTMLTextAreaElement.prototype, "scrollHeight", {
    configurable: true,
    get() {
      return scrollHeight;
    },
  });

  try {
    await callback();
  } finally {
    if (descriptor) {
      Object.defineProperty(
        HTMLTextAreaElement.prototype,
        "scrollHeight",
        descriptor
      );
    } else {
      delete HTMLTextAreaElement.prototype.scrollHeight;
    }
  }
}

async function waitForResize() {
  await new Promise((resolve) => requestAnimationFrame(resolve));
}

module("Integration | Modifier | autoResizeTextarea", function (hooks) {
  setupRenderingTest(hooks);

  test("sets overflowY to auto when scrollHeight exceeds max-height", async function (assert) {
    await withScrollHeight(300, async () => {
      await render(
        <template>
          {{! template-lint-disable no-inline-styles }}
          <textarea
            class="test-textarea"
            style="max-height: 200px"
            {{autoResizeTextarea manageOverflow=true}}
          />
        </template>
      );
      await waitForResize();

      assert.strictEqual(
        document.querySelector(".test-textarea").style.overflowY,
        "auto"
      );
    });
  });

  test("sets overflowY to hidden when scrollHeight is within max-height", async function (assert) {
    await withScrollHeight(100, async () => {
      await render(
        <template>
          {{! template-lint-disable no-inline-styles }}
          <textarea
            class="test-textarea"
            style="max-height: 200px"
            {{autoResizeTextarea manageOverflow=true}}
          />
        </template>
      );
      await waitForResize();

      assert.strictEqual(
        document.querySelector(".test-textarea").style.overflowY,
        "hidden"
      );
    });
  });

  test("does not set overflowY when manageOverflow is not enabled", async function (assert) {
    await withScrollHeight(300, async () => {
      await render(
        <template>
          {{! template-lint-disable no-inline-styles }}
          <textarea
            class="test-textarea"
            style="max-height: 200px"
            {{autoResizeTextarea}}
          />
        </template>
      );
      await waitForResize();

      assert.strictEqual(
        document.querySelector(".test-textarea").style.overflowY,
        ""
      );
    });
  });
});
