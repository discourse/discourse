import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Route | user-activity AI share guards", function (hooks) {
  setupTest(hooks);
  hooks.afterEach(() => sinon.restore());

  test("administrators are redirected when the target model is missing or invalid", function (assert) {
    const router = this.owner.lookup("service:router");
    const redirect = {};
    const replaceWith = sinon.stub(router, "replaceWith").returns(redirect);
    const targets = [
      undefined,
      null,
      {},
      { id: 0 },
      { id: -1 },
      { id: -100 },
      { id: "5" },
    ];

    for (const name of [
      "shared-ai-artifacts",
      "shared-ai-conversations",
      "shared-artifacts",
    ]) {
      const route = this.owner.lookup(`route:user-activity.${name}`);
      route.set("currentUser", { id: 19, admin: true });
      route.set("siteSettings", { discourse_ai_enabled: true });
      const modelFor = sinon.stub(route, "modelFor");

      for (const target of targets) {
        modelFor.returns(target);
        replaceWith.resetHistory();
        assert.strictEqual(
          route.beforeModel(),
          redirect,
          `${name} rejects a missing or nonpositive target`
        );
        assert.true(
          replaceWith.calledOnceWithExactly("userActivity.index"),
          `${name} redirects to activity, never the self feed`
        );
      }
    }
  });
});
