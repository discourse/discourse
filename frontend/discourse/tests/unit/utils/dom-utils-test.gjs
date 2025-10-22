import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import domUtils from "discourse/lib/dom-utils";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Unit | Utils | dom-utils", function (hooks) {
  setupRenderingTest(hooks);

  test("offset", async function (assert) {
    await render(<template><DButton @translatedLabel="baz" /></template>);
    const element = document.querySelector(".btn");
    const offset = domUtils.offset(element);
    const rect = element.getBoundingClientRect();

    assert.deepEqual(offset, {
      top: rect.top + window.scrollY,
      left: rect.left + window.scrollX,
    });
  });

  test("position", async function (assert) {
    await render(<template><DButton @translatedLabel="baz" /></template>);

    const element = document.querySelector(".btn");
    const position = domUtils.position(element);

    assert.deepEqual(position, {
      top: element.offsetTop,
      left: element.offsetLeft,
    });
  });
});
