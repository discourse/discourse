import { module, test } from "qunit";
import { cook } from "discourse/lib/text";

const opts = {
  siteSettings: {
    enable_emoji: true,
    emoji_set: "twitter",
    highlighted_languages: "json|ruby|javascript",
    default_code_lang: "auto",
  },
  censoredWords: "shucks|whiz|whizzer",
  getURL: (url) => url,
};

module("lib:details-cooked-test", function () {
  test("details", async function (assert) {
    const testCooked = async (input, expected, text) => {
      const cooked = (await cook(input, opts)).toString();
      assert.strictEqual(cooked, expected, text);
    };
    await testCooked(
      `<details><summary>Info</summary>coucou</details>`,
      `<details><summary>Info</summary>coucou</details>`,
      "manual HTML for details"
    );

    await testCooked(
      "[details=testing]\ntest\n[/details]",
      `<details>
<summary>
testing</summary>
<p>test</p>
</details>`
    );
  });
});
