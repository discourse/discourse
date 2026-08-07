import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Routes | chat | anonymous", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.testOwner = getOwner(this);
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("direct messages redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.direct-messages");
    sinon.stub(route.router, "replaceWith");

    route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });

  test("new message redirects anonymous users to public channels", async function (assert) {
    const route = this.testOwner.lookup("route:chat.new-message");
    const transition = { abort: sinon.stub() };
    sinon.stub(route.router, "transitionTo");

    await route.beforeModel(transition);

    assert.true(transition.abort.calledOnce);
    assert.true(route.router.transitionTo.calledWith("chat.channels"));
  });

  test("search redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.search");
    sinon.stub(route.router, "transitionTo");

    route.redirect();

    assert.true(route.router.transitionTo.calledWith("chat.channels"));
  });

  test("starred channels redirects anonymous users to public channels", async function (assert) {
    const route = this.testOwner.lookup("route:chat.starred-channels");
    sinon.stub(route.router, "replaceWith");

    await route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });

  test("threads redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.threads");
    sinon.stub(route.router, "replaceWith");

    route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });
});
