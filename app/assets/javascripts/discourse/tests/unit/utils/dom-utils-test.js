import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";
import domUtils from "discourse-common/utils/dom-utils";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module("Unit | Utils | dom-utils", function (hooks) {
  setupRenderingTest(hooks);

  test("offset", async function (assert) {
    await render(hbs`<DButton @translatedLabel="baz" />`);
    const element = document.querySelector(".btn");
    const offset = domUtils.offset(element);
    const rect = element.getBoundingClientRect();

    assert.deepEqual(offset, {
      top: rect.top + window.scrollY,
      left: rect.left + window.scrollX,
    });
  });

  test("position", async function (assert) {
    await render(hbs`<DButton @translatedLabel="baz" />`);

    const element = document.querySelector(".btn");
    const position = domUtils.position(element);

    assert.deepEqual(position, {
      top: element.offsetTop,
      left: element.offsetLeft,
    });
  });
});
