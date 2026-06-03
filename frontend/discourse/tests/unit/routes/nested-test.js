import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Route | nested", function (hooks) {
  setupTest(hooks);

  test("contributes topic title tokens", function (assert) {
    const route = this.owner.lookup("route:nested");
    const category = EmberObject.create({
      name: "Support",
      isUncategorizedCategory: false,
    });
    const topic = EmberObject.create({
      title: "Nested topic title",
      category,
    });
    const tokens = [];

    route.siteSettings.topic_page_title_includes_category = true;
    route.currentModel = { topic };

    route._collectTitleTokens(tokens);

    assert.deepEqual(
      tokens,
      ["Nested topic title", "Support"],
      "the nested route contributes the same title tokens as the topic route"
    );
  });
});
