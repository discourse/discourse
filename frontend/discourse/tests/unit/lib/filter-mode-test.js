import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  filterTypeForMode,
  serverFilterForMode,
} from "discourse/lib/filter-mode";

module("Unit | Lib | filter-mode", function (hooks) {
  setupTest(hooks);

  test("filterTypeForMode returns the last segment", function (assert) {
    assert.strictEqual(filterTypeForMode("latest"), "latest");
    assert.strictEqual(filterTypeForMode("c/bug/1/l/votes"), "votes");
    assert.strictEqual(filterTypeForMode(undefined), undefined);
  });

  test("serverFilterForMode derives the filter the server reports", function (assert) {
    const cases = {
      latest: "latest",
      hot: "hot",
      filter: "filter",
      "c/bug/1/l/latest": "latest",
      "c/bug/1/l/votes": "votes",
      "c/bug/1/none/l/votes": "votes",
      // a category slug may itself be "l"
      "c/l/1/l/latest": "latest",
      "tag/5/l/latest": "latest",
      "tags/c/bug/1/5/l/hot": "hot",
    };

    for (const [mode, expected] of Object.entries(cases)) {
      assert.strictEqual(serverFilterForMode(mode), expected, mode);
    }
  });

  test("serverFilterForMode gives up on modes that end in a name", function (assert) {
    const undecidable = [
      "tags/intersection/alpha/beta",
      "topics/created-by/sam",
      "topics/groups/staff",
      "topics/private-messages/sam",
      "",
      undefined,
    ];

    for (const mode of undecidable) {
      assert.strictEqual(serverFilterForMode(mode), undefined, `${mode}`);
    }
  });
});
