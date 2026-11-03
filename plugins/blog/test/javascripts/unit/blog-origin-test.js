import { module, test } from "qunit";
import blogOrigin from "discourse/plugins/blog/discourse/lib/blog-origin";

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
});
