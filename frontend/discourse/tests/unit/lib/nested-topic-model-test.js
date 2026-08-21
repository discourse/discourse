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

  test("records direct-page and visible-pinned-root metadata", function (assert) {
    const model = processNestedRootResponse({
      data: {
        topic: { id: 1, slug: "nested-topic" },
        roots: [
          { id: 10, post_number: 2, children: [] },
          { id: 11, post_number: 3, children: [] },
        ],
        pinned_post_ids: [10, 99],
        root_page_size: 25,
        root_count: 100,
      },
      params: {},
      site: this.owner.lookup("service:site"),
      siteSettings: this.owner.lookup("service:site-settings"),
      store: this.owner.lookup("service:store"),
    });

    assert.strictEqual(model.rootPageSize, 25);
    assert.strictEqual(model.rootWindowStart, 0);
    assert.deepEqual(
      model.rootWindowPages,
      [
        {
          page: 0,
          nodeCount: 2,
          hasMoreRoots: false,
          rootPageSize: 25,
        },
      ],
      "records the initial server-page boundary for cache restoration"
    );
    assert.strictEqual(
      model.pinnedRootCount,
      1,
      "counts only pinned roots present in the logical list"
    );
  });
});
