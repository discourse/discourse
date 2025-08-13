import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { buildQuote } from "discourse/lib/quote";
import DiscourseMarkdownIt from "discourse-markdown-it";

module("Unit | Utility | build-quote", function (hooks) {
  setupTest(hooks);

  test("quotes", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("post", {
      cooked: "<p><b>lorem</b> ipsum</p>",
      username: "eviltrout",
      post_number: 1,
      topic_id: 2,
    });

    assert.strictEqual(
      buildQuote(post, undefined),
      "",
      "empty string for undefined content"
    );
    assert.strictEqual(
      buildQuote(post, null),
      "",
      "empty string for null content"
    );
    assert.strictEqual(
      buildQuote(post, ""),
      "",
      "empty string for empty string content"
    );

    assert.strictEqual(
      buildQuote(post, "lorem"),
      '[quote="eviltrout, post:1, topic:2"]\nlorem\n[/quote]\n\n',
      "correctly formats quotes"
    );

    assert.strictEqual(
      buildQuote(post, "  lorem \t  "),
      '[quote="eviltrout, post:1, topic:2"]\nlorem\n[/quote]\n\n',
      "trims white spaces before & after the quoted contents"
    );

    assert.strictEqual(
      buildQuote(post, "lorem ipsum", { full: true }),
      '[quote="eviltrout, post:1, topic:2, full:true"]\nlorem ipsum\n[/quote]\n\n',
      "marks quotes as full if the `full` option is passed"
    );

    assert.strictEqual(
      buildQuote(post, "**lorem** ipsum"),
      '[quote="eviltrout, post:1, topic:2"]\n**lorem** ipsum\n[/quote]\n\n',
      "keeps BBCode formatting"
    );
  });

  test("quoting a quote", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("post", {
      cooked: DiscourseMarkdownIt.minimal().cook(
        '[quote="sam, post:1, topic:1, full:true"]\nhello\n[/quote]\n*Test*'
      ),
      username: "eviltrout",
      post_number: 1,
      topic_id: 2,
    });

    const quote = buildQuote(
      post,
      '[quote="sam, post:1, topic:1, full:true"]\nhello\n[/quote]'
    );

    assert.strictEqual(
      quote,
      '[quote="eviltrout, post:1, topic:2"]\n[quote="sam, post:1, topic:1, full:true"]\nhello\n[/quote]\n[/quote]\n\n',
      "allows quoting a quote"
    );
  });

  test("applying a value transformation", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("post", {
      cooked: "<p><b>lorem</b> ipsum</p>",
      username: "eviltrout",
      post_number: 1,
      topic_id: 2,
    });

    withPluginApi((api) => {
      api.registerValueTransformer("quote-params", ({ value }) => {
        value[0] = "New transformed name";
        return value;
      });
    });

    const quote = buildQuote(post, "hello");
    assert.strictEqual(
      quote,
      '[quote="New transformed name, post:1, topic:2"]\nhello\n[/quote]\n\n',
      "it transforms the quote params name"
    );
  });
});
