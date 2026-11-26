/* eslint-disable ember/no-jquery */
import $ from "jquery";
import { module, test } from "qunit";
import sinon from "sinon";
import { createClientSettled } from "discourse/initializers/rails-testing";
import { sendBeaconPageview } from "discourse/lib/beacon-pageview";

module("Unit | Initializer | rails-testing", function (hooks) {
  hooks.beforeEach(function () {
    this.doc = document.implementation.createHTMLDocument();
    this.clientSettled = createClientSettled(this.doc);
    this.clock = sinon.useFakeTimers({
      toFake: ["setTimeout", "clearTimeout"],
    });
  });

  function request(doc, url) {
    const xhr = {};
    const settings = { url };
    $(doc).trigger("ajaxSend", [xhr, settings]);
    return (event = "ajaxComplete") => $(doc).trigger(event, [xhr, settings]);
  }

  test("waits for follow-up requests started by a completion handler", async function (assert) {
    const finishFirst = request(this.doc, "/first");
    const settled = sinon.spy();
    const waiting = this.clientSettled(100).then(settled);
    await this.clock.tickAsync(10);
    assert.false(settled.called, "the original request is still pending");

    finishFirst();
    await Promise.resolve();
    const finishSecond = request(this.doc, "/second");
    await this.clock.tickAsync(10);
    assert.false(
      settled.called,
      "the request started after completion is pending"
    );

    finishSecond("ajaxError");
    await this.clock.tickAsync(10);
    await waiting;
    assert.true(settled.calledOnce, "a failed request also unblocks the wait");
  });

  test("waits for both timer turns after a captured DOM event", async function (assert) {
    const button = this.doc.createElement("button");
    this.doc.body.append(button);
    button.click();
    const settled = sinon.spy();
    const waiting = this.clientSettled(100).then(settled);

    await this.clock.tickAsync(0);
    assert.false(settled.called, "a single timer turn is not enough");
    await this.clock.tickAsync(2);
    await waiting;
    assert.true(settled.calledOnce, "two timer turns unblock the wait");
  });

  test("does not wait for continuous requests", async function (assert) {
    request(this.doc, "/message-bus/site/poll");
    request(this.doc, "/presence/get");

    assert.true(
      await this.clientSettled(100),
      "continuous requests are ignored"
    );
  });

  test("waits for a beacon after tracked work completes", async function (assert) {
    const beacon = Promise.withResolvers();
    sinon.stub(window, "fetch").returns(beacon.promise);
    sendBeaconPageview({ sessionId: "test-session", url: "/first" });

    const finish = request(this.doc, "/first.json");
    const settled = sinon.spy();
    const waiting = this.clientSettled(100).then(settled);
    finish();
    await this.clock.tickAsync(10);
    assert.false(
      settled.called,
      "request completion did not bypass the beacon"
    );

    beacon.resolve(new Response());
    await this.clock.tickAsync(10);
    await waiting;
    assert.true(settled.calledOnce, "the beacon completion unblocks the wait");
  });

  test("reports pending work without disturbing another waiter's deadline", async function (assert) {
    const button = this.doc.createElement("button");
    button.className = "btn primary";
    this.doc.body.append(button);
    const finish = request(this.doc, "/slow.json");
    const beacon = Promise.withResolvers();
    sinon.stub(window, "fetch").returns(beacon.promise);
    sendBeaconPageview({ sessionId: "test-session", url: "/slow" });

    button.click();
    const first = assert.rejects(
      this.clientSettled(0),
      /after 0ms\.\n  Pending requests: \/slow\.json\n  Pending DOM events: click on button\.btn\.primary\n  Pending beacon pageview requests/,
      "the timeout reports each category of pending work"
    );
    const second = this.clientSettled(100);
    await this.clock.tickAsync(10);
    await first;

    finish();
    beacon.resolve(new Response());
    await this.clock.tickAsync(10);
    assert.true(await second, "the other waiter still settles normally");
  });
});
