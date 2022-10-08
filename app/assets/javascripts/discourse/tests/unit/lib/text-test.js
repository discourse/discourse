import { module, test } from "qunit";
import { parseAsync } from "discourse/lib/text";

module("Unit | Utility | text", function () {
  test("parseAsync", async function (assert) {
    await parseAsync("**test**").then((tokens) => {
      assert.strictEqual(
        tokens[1].children[1].type,
        "strong_open",
        "it parses the raw markdown"
      );
    });
  });
});
