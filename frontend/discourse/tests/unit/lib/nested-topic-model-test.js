import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  processNestedContextResponse,
  processNestedRootResponse,
} from "discourse/lib/nested-topic-model";

module("Unit | Lib | nested-topic-model", function (hooks) {
  setupTest(hooks);

  test("focuses the resolved post rather than a missing requested post", function (assert) {
    const model = processNestedContextResponse({
      data: {
        topic: { id: 1, slug: "nested-topic" },
        target_post: { id: 2, post_number: 2, children: [] },
      },
      params: { post_number: 3 },
      sort: "old",
      site: this.owner.lookup("service:site"),
      store: this.owner.lookup("service:store"),
    });

    assert.strictEqual(model.postNumber, 2, "uses the resolved post number");
    assert.strictEqual(
      model.targetPostNumber,
      2,
      "highlights the resolved post"
    );
  });

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
