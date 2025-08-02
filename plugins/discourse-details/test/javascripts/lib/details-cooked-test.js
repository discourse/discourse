import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cook } from "discourse/lib/text";

module("lib:details-cooked-test", (hooks) => {
  setupTest(hooks);

  test("details", async (assert) => {
    const testCooked = async (input, expected, text) => {
      const cooked = (await cook(input)).toString();
      assert.strictEqual(cooked, expected, text);
    };

    await testCooked(
      `<details><summary>Info</summary>coucou</details>`,
      `<details><summary>Info</summary>coucou</details>`,
      "manual HTML for details"
    );

    await testCooked(
      `[details=test'ing all the things]\ntest\n[/details]`,
      `<details>\n<summary>\ntest'ing all the things</summary>\n<p>test</p>\n</details>`,
      "details with spaces and a single quote"
    );

    await testCooked(
      `[details=”test'ing all the things”]\ntest\n[/details]`,
      `<details>\n<summary>\ntest'ing all the things</summary>\n<p>test</p>\n</details>`,
      "details surrounded by finnish double quotes"
    );
  });
});
