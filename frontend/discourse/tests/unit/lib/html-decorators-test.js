import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  applyHtmlDecorators,
  NULL_HELPER,
  registerHtmlDecorator,
  resetHtmlDecorators,
} from "discourse/ui-kit/d-decorated-html";

module("Unit | Utility | html-decorators", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.firstOwner = {};
    this.secondOwner = {};
  });

  hooks.afterEach(function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
    resetHtmlDecorators();
  });

  test("owner cleanup preserves duplicate decorators and their returned cleanup", function (assert) {
    const decorator = (element) => {
      const child = document.createElement("span");
      child.textContent = "decorated";
      element.appendChild(child);
      return () => child.remove();
    };
    registerHtmlDecorator(decorator, undefined, { owner: this.firstOwner });
    registerHtmlDecorator(decorator, undefined, { owner: this.secondOwner });
    const element = document.createElement("div");
    const cleanups = applyHtmlDecorators(element, NULL_HELPER);
    assert
      .dom("span", element)
      .exists({ count: 2 }, "both registrations decorate");

    cleanups.forEach((cleanup) => cleanup());
    assert
      .dom("span", element)
      .doesNotExist("returned cleanups remove their decorations");
    run(() => destroy(this.firstOwner));
    const remainingCleanups = applyHtmlDecorators(element, NULL_HELPER);
    assert
      .dom("span", element)
      .exists({ count: 1 }, "the surviving owner still decorates");
    remainingCleanups.forEach((cleanup) => cleanup());
    assert
      .dom("span", element)
      .doesNotExist("the surviving decorator still returns cleanup");
  });

  test("old owner cleanup preserves decorators registered after a reset", function (assert) {
    const decorator = (element) => element.classList.add("decorated");
    registerHtmlDecorator(decorator, undefined, { owner: this.firstOwner });
    resetHtmlDecorators();
    registerHtmlDecorator(decorator, undefined, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));
    const element = document.createElement("div");
    applyHtmlDecorators(element, NULL_HELPER);

    assert
      .dom(element)
      .hasClass("decorated", "the new registry keeps its decorator");
  });
});
