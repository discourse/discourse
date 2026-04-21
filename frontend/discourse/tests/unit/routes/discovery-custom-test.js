import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Unit | Route | discovery-custom", function (hooks) {
  setupTest(hooks);

  test("model returns null by default when no transformer is registered", async function (assert) {
    const route = this.owner.lookup("route:discovery.custom");

    assert.strictEqual(await route.model({}), null);
  });

  test("custom-homepage-model value transformer can provide the model", async function (assert) {
    const route = this.owner.lookup("route:discovery.custom");
    const homepageModel = { latest: [{ id: 1 }], hot: [{ id: 2 }] };

    withPluginApi((api) => {
      api.registerValueTransformer(
        "custom-homepage-model",
        () => homepageModel
      );
    });

    assert.strictEqual(await route.model({}), homepageModel);
  });

  test("custom-homepage-model value transformer can be async", async function (assert) {
    const route = this.owner.lookup("route:discovery.custom");
    const homepageModel = { leaderboard: { users: [] } };

    withPluginApi((api) => {
      api.registerValueTransformer(
        "custom-homepage-model",
        async () => homepageModel
      );
    });

    assert.strictEqual(await route.model({}), homepageModel);
  });

  test("custom-homepage-model value transformer receives queryParams in context", async function (assert) {
    const route = this.owner.lookup("route:discovery.custom");
    let receivedContext;

    withPluginApi((api) => {
      api.registerValueTransformer("custom-homepage-model", ({ context }) => {
        receivedContext = context;
        return null;
      });
    });

    await route.model({ q: "search term" });

    assert.deepEqual(receivedContext.queryParams, { q: "search term" });
  });

  test("multiple value transformers compose, each receiving the previous value", async function (assert) {
    const route = this.owner.lookup("route:discovery.custom");

    withPluginApi((api) => {
      api.registerValueTransformer("custom-homepage-model", () => ({ a: 1 }));
      api.registerValueTransformer("custom-homepage-model", ({ value }) => ({
        ...value,
        b: 2,
      }));
    });

    assert.deepEqual(await route.model({}), { a: 1, b: 2 });
  });
});
