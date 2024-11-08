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

module("Unit | Service | Experimental Lightbox", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.lightbox = getOwner(this).lookup("service:lightbox");
    this.appEvents = getOwner(this).lookup("service:app-events");

    document.querySelector("#ember-testing").innerHTML =
      generateLightboxMarkup();
  });

  hooks.afterEach(function () {
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("Does not add event listener if no lightboxes are found", async function (assert) {
    const container = document.createElement("div");
    const addEventListenerSpy = sinon.spy(container, "addEventListener");

    await this.lightbox.setupLightboxes({ container, selector: ".lightbox" });

    assert.false(addEventListenerSpy.called, "does not add event listener");

    addEventListenerSpy.restore();
  });

  test("Adds event listener if lightboxes are found", async function (assert) {
    const container = document.querySelector(".lightbox-wrapper");
    const addEventListenerSpy = sinon.spy(container, "addEventListener");

    await this.lightbox.setupLightboxes({ container, selector: ".lightbox" });

    assert.true(addEventListenerSpy.calledOnce, "adds event listener");

    addEventListenerSpy.restore();
  });

  test("Correctly sets event listeners", async function (assert) {
    const container = document.querySelector(".lightbox-wrapper");
    const openLightboxSpy = sinon.spy(this.lightbox, "openLightbox");
    const removeEventListenerSpy = sinon.spy(container, "removeEventListener");
    const clickTarget = container.querySelector(".lightbox");

    await this.lightbox.setupLightboxes({
      container,
      selector: ".lightbox",
      clickTarget,
    });

    await click(".lightbox");

    container.appendChild(document.createElement("p"));

    await click(container.querySelector("p"));

    assert.true(
      openLightboxSpy.calledWith({
        container,
        selector: ".lightbox",
        clickTarget,
      }),
      "calls openLightbox on lightboxed element click"
    );

    assert.true(
      openLightboxSpy.calledOnce,
      "only calls open lightbox when lightboxed element is clicked"
    );

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      1,
      "correctly stores lightbox click elements for cleanup"
    );

    await this.lightbox.cleanupLightboxes();

    assert.true(
      removeEventListenerSpy.calledOnce,
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

  test("correctly calls the lightbox:open event", async function (assert) {
    const done = assert.async();
    const container = document.querySelector(".lightbox-wrapper");

    await this.lightbox.setupLightboxes({ container, selector: ".lightbox" });

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

    await click(".lightbox");

    assert.true(appEventsTriggerSpy.calledWith(expectedEvent));

    appEventsTriggerSpy.restore();
  });

  test("correctly calls the lightbox:close event", async function (assert) {
    const container = document.querySelector(".lightbox-wrapper");

    await this.lightbox.setupLightboxes({ container, selector: ".lightbox" });

    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.CLOSE, () => {
      assert.step("lightbox closed");
    });

    await click(".lightbox");

    await this.lightbox.closeLightbox();
    assert.verifySteps(["lightbox closed"]);
  });

  test("correctly responds to the lightbox:clean event", async function (assert) {
    const container = document.querySelector(".lightbox-wrapper");

    await this.lightbox.setupLightboxes({ container, selector: ".lightbox" });

    await click(".lightbox");

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      1,
      "correctly stores lightbox click elements for cleanup"
    );

    assert.true(this.lightbox.lightboxIsOpen, "sets lightboxIsOpen to true");

    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.CLEAN);

    assert.strictEqual(
      this.lightbox.lightboxClickElements.length,
      0,
      "correctly removes stored entry from lightboxClickElements on cleanup"
    );

    assert.false(this.lightbox.lightboxIsOpen, "sets lightboxIsOpen to false");
  });
});
