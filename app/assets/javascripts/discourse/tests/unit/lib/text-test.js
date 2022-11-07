import { module, test } from "qunit";
import { cookAsync, excerpt, parseAsync } from "discourse/lib/text";

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

  test("excerpt", async function (assert) {
    let cooked = await cookAsync("Hello! :wave:");
    assert.strictEqual(
      await excerpt(cooked, 300),
      'Hello! <img src="/images/emoji/twitter/wave.png?v=12" title=":wave:" class="emoji" alt=":wave:" loading="lazy" width="20" height="20">'
    );

    cooked = await cookAsync("[:wave:](https://example.com)");
    assert.strictEqual(
      await excerpt(cooked, 300),
      '<a href="https://example.com"><img src="/images/emoji/twitter/wave.png?v=12" title=":wave:" class="emoji only-emoji" alt=":wave:" loading="lazy" width="20" height="20"></a>'
    );

    cooked = await cookAsync('<script>alert("hi")</script>');
    assert.strictEqual(await excerpt(cooked, 300), "");

    cooked = await cookAsync("[`<script>alert('hi')</script>`]()");
    assert.strictEqual(
      await excerpt(cooked, 300),
      "<a><code>&lt;script&gt;alert('hi')&lt;/script&gt;</code></a>"
    );
  });
});
