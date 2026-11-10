import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { updatePosition } from "discourse/float-kit/lib/update-position";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | FloatKit | preserve-placement", function (hooks) {
  setupRenderingTest(hooks);

  test("retains the opening placement after filtering and resets for a new float", async function (assert) {
    await render(
      <template>
        <div data-test-float></div>
      </template>
    );
    const trigger = {
      getBoundingClientRect: () =>
        new DOMRect(100, window.innerHeight - 100, 100, 20),
    };
    const options = {
      placement: "bottom-start",
      fallbackPlacements: ["top-start"],
      preservePlacement: true,
      strategy: "fixed",
      offset: 0,
      padding: 0,
    };
    const content = find("[data-test-float]");
    content.style.cssText = "width: 100px; height: 200px; position: fixed;";
    await updatePosition(trigger, content, options);
    assert.strictEqual(
      content.dataset.placement,
      "top-start",
      "opens above when it cannot fit below"
    );

    content.style.height = "20px";
    await updatePosition(trigger, content, options);
    assert.strictEqual(
      content.dataset.placement,
      "top-start",
      "stays above after the results shrink"
    );

    await updatePosition(trigger, content, {
      ...options,
      preservePlacement: false,
    });
    assert.strictEqual(
      content.dataset.placement,
      "bottom-start",
      "normal menus can flip after resizing"
    );

    await render(
      <template>
        <div data-test-reopened-float></div>
      </template>
    );
    const reopened = find("[data-test-reopened-float]");
    reopened.style.cssText = "width: 100px; height: 20px; position: fixed;";
    await updatePosition(trigger, reopened, options);
    assert.strictEqual(
      reopened.dataset.placement,
      "bottom-start",
      "a new opening chooses its own placement"
    );
  });
});
