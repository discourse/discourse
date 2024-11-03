import { getOwner } from "@ember/owner";
import { click } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { LIGHTBOX_APP_EVENT_NAMES } from "discourse/lib/lightbox/constants";
import {
  generateLightboxMarkup,
  generateLightboxObject,
} from "discourse/tests/helpers/lightbox-helpers";
import domFromString from "discourse-common/lib/dom-from-string";

module("Unit | Service | Experimental Lightbox", function (hooks) {
  setupTest(hooks);

  const wrap = domFromString(generateLightboxMarkup())[0];
  const selector = ".lightbox";

  hooks.beforeEach(function () {
    this.lightbox = getOwner(this).lookup("service:lightbox");
    this.appEvents = getOwner(this).lookup("service:app-events");
  });

  test("Lightbox Service has appEvents", async function (assert) {
    assert.ok(this.lightbox.appEvents);
  });

  test("Does not add event listener if no lightboxes are found", async function (assert) {
    const container = document.createElement("div");
    const addEventListenerSpy = sinon.spy(container, "addEventListener");

    await this.lightbox.setupLightboxes({ container, selector });

    assert.strictEqual(
      addEventListenerSpy.called,
      false,
      "does not add event listener"
    );

    addEventListenerSpy.restore();
  });

  test("Adds event listener if lightboxes are found", async function (assert) {
    const container = wrap.cloneNode(true);
    const addEventListenerSpy = sinon.spy(container, "addEventListener");

    await this.lightbox.setupLightboxes({ container, selector });

    assert.strictEqual(
      addEventListenerSpy.calledOnce,
      true,
      "adds event listener"
    );

    addEventListenerSpy.restore();
  });

  test("Correctly sets event listeners", async function (assert) {
    const container = wrap.cloneNode(true);

    const openLightboxSpy = sinon.spy(this.lightbox, "openLightbox");
    const removeEventListenerSpy = sinon.spy(container, "removeEventListener");
    const clickTarget = container.querySelector(selector);

    await this.lightbox.setupLightboxes({ container, selector, clickTarget });

    await click(container.querySelector(selector));

    container.appendChild(document.createElement("p"));

    await click(container.querySelector("p"));

    assert.strictEqual(
      openLightboxSpy.calledWith({ container, selector, clickTarget }),
      true,
      "calls openLightbox on lightboxed element click"
    );

    assert.strictEqual(
      openLightboxSpy.calledOnce,
      true,
      "only calls open lightbox when lightboxed element is clicked"
    );

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      1,
      "correctly stores lightbox click elements for cleanup"
    );

    await this.lightbox.cleanupLightboxes();

    assert.strictEqual(
      removeEventListenerSpy.calledOnce,
      true,
      "removes event listener from element on cleanup"
    );

    removeEventListenerSpy.restore();

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      0,
      "correctly removes stored entry from lightboxClickElements on cleanup"
    );

    openLightboxSpy.restore();
    removeEventListenerSpy.restore();
  });

  test(`correctly calls the lightbox:open event`, async function (assert) {
    const done = assert.async();
    const container = wrap.cloneNode(true);

    await this.lightbox.setupLightboxes({ container, selector });

    const appEventsTriggerSpy = sinon.spy(this.appEvents, "trigger");

    const expectedObject = {
      ...generateLightboxObject(),
      options: this.lightbox.options,
      callbacks: this.lightbox.callbacks,
    };

    const expectedEvent = LIGHTBOX_APP_EVENT_NAMES.OPEN;

    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.OPEN, (args) => {
      assert.deepEqual(args, expectedObject);
      done();
    });

    await click(container.querySelector(selector));

    assert.ok(appEventsTriggerSpy.calledWith(expectedEvent));

    appEventsTriggerSpy.restore();
  });

  test("correctly calls the lightbox:close event", async function (assert) {
    const container = wrap.cloneNode(true);

    await this.lightbox.setupLightboxes({ container, selector });

    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.CLOSE, () => {
      assert.step("lightbox closed");
    });

    await click(selector, container);

    await this.lightbox.closeLightbox();
    assert.verifySteps(["lightbox closed"]);
  });

  test(`correctly responds to the lightbox:clean event`, async function (assert) {
    const container = wrap.cloneNode(true);

    await this.lightbox.setupLightboxes({ container, selector });

    await click(container.querySelector(".lightbox"));

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      1,
      "correctly stores lightbox click elements for cleanup"
    );

    assert.strictEqual(
      this.lightbox.lightboxIsOpen,
      true,
      "sets lightboxIsOpen to true"
    );

    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.CLEAN);

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      0,
      "correctly removes stored entry from lightboxClickElements on cleanup"
    );

    assert.strictEqual(
      this.lightbox.lightboxIsOpen,
      false,
      "sets lightboxIsOpen to false"
    );
  });
});
