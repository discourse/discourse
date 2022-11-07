import { module, test } from "qunit";
import { cookAsync, excerpt } from "discourse/lib/text";

module("Unit | Utility | text", function () {
  test("excerpt", async function (assert) {
    let cooked = await cookAsync("Hello! :wave:");
    assert.strictEqual(
      await excerpt(cooked, 300),
      'Hello! <img src="/images/emoji/google_classic/wave.png?v=12" title=":wave:" class="emoji" alt=":wave:" loading="lazy" width="20" height="20">'
    );

    cooked = await cookAsync("[:wave:](https://example.com)");
    assert.strictEqual(
      await excerpt(cooked, 300),
      '<a href="https://example.com"><img src="/images/emoji/google_classic/wave.png?v=12" title=":wave:" class="emoji only-emoji" alt=":wave:" loading="lazy" width="20" height="20"></a>'
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
