import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { processNestedRootResponse } from "discourse/lib/nested-topic-model";

module("Unit | Lib | nested-topic-model", function (hooks) {
  setupTest(hooks);

  test("preserves requested and effective sorts", function (assert) {
    const model = processNestedRootResponse({
      data: {
        topic: { id: 1, slug: "nested-topic" },
        roots: [],
        sort: "hot",
        effective_sort: "top",
      },
      params: {},
      site: this.owner.lookup("service:site"),
      siteSettings: this.owner.lookup("service:site-settings"),
      store: this.owner.lookup("service:store"),
    });

    assert.strictEqual(model.sort, "hot", "keeps Hot selected");
    assert.strictEqual(
      model.effectiveSort,
      "top",
      "records the ordering used by the server"
    );
  });
});
