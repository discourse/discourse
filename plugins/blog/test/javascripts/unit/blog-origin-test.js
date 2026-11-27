import { module, test } from "qunit";
import blogOrigin, {
  embeddingBlogOrigin,
} from "discourse/plugins/blog/discourse/lib/blog-origin";

module("Unit | Lib | blog-origin", function () {
  test("returns the origin of the configured blog URL", function (assert) {
    assert.strictEqual(
      blogOrigin("https://blog.example.com/some/path"),
      "https://blog.example.com"
    );
  });

  test("returns null for values that cannot be parsed", function (assert) {
    assert.strictEqual(blogOrigin(""), null, "a blank setting has no origin");
    assert.strictEqual(
      blogOrigin("blog.example.com"),
      null,
      "a scheme-less host"
    );
    assert.strictEqual(blogOrigin(undefined), null, "an unset setting");
  });

  test("embeddingBlogOrigin picks the blog the embedding page belongs to", function (assert) {
    const blogs = [
      { base_url: "https://blog.example.com" },
      { base_url: "https://engineering.example.com" },
    ];

    assert.strictEqual(
      embeddingBlogOrigin(blogs, "https://engineering.example.com/story"),
      "https://engineering.example.com",
      "the referrer names the blog showing the discussion"
    );
    assert.strictEqual(
      embeddingBlogOrigin(blogs, "https://elsewhere.example.com/"),
      null,
      "a page on no blog's origin gets no messages"
    );
  });

  test("embeddingBlogOrigin trusts the only blog origin without a referrer", function (assert) {
    const blogs = [
      { base_url: "https://forum.example.com/blog" },
      { base_url: "https://forum.example.com/blog/engineering" },
    ];

    assert.strictEqual(
      embeddingBlogOrigin(blogs, ""),
      "https://forum.example.com",
      "blogs under the forum share its origin"
    );
  });
});
