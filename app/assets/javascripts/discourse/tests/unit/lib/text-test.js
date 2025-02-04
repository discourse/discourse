import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cook, excerpt, parseAsync, parseMentions } from "discourse/lib/text";

module("Unit | Utility | text", function (hooks) {
  setupTest(hooks);

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
    let cooked = await cook("Hello! :wave:");
    assert.strictEqual(
      await excerpt(cooked, 300),
      'Hello! <img src="/images/emoji/twitter/wave.png?v=12" title=":wave:" class="emoji" alt=":wave:" loading="lazy" width="20" height="20">'
    );

    cooked = await cook("[:wave:](https://example.com)");
    assert.strictEqual(
      await excerpt(cooked, 300),
      '<a href="https://example.com"><img src="/images/emoji/twitter/wave.png?v=12" title=":wave:" class="emoji only-emoji" alt=":wave:" loading="lazy" width="20" height="20"></a>'
    );

    cooked = await cook('<script>alert("hi")</script>');
    assert.strictEqual(await excerpt(cooked, 300), "");

    cooked = await cook("[`<script>alert('hi')</script>`]()");
    assert.strictEqual(
      await excerpt(cooked, 300),
      "<a><code>&lt;script&gt;alert('hi')&lt;/script&gt;</code></a>"
    );
  });
});

module("Unit | Utility | text | parseMentions", function (hooks) {
  setupTest(hooks);

  test("parses mentions from markdown", async function (assert) {
    const markdown = "Hey @user1, @user2, @group1, @group2, @here, @all";
    const mentions = await parseMentions(markdown);
    assert.deepEqual(mentions, [
      "user1",
      "user2",
      "group1",
      "group2",
      "here",
      "all",
    ]);
  });

  test("ignores duplicated mentions", async function (assert) {
    const markdown = "Hey @john, @john, @john, @john";
    const mentions = await parseMentions(markdown);
    assert.deepEqual(mentions, ["john"]);
  });

  test("ignores mentions in codeblocks", async function (assert) {
    const markdown = `Hey
    \`\`\`
      def foo
        @bar = true
      end
    \`\`\`
    `;
    const mentions = await parseMentions(markdown);
    assert.strictEqual(mentions.length, 0);
  });
});
