import { module, test } from "qunit";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

module("Discourse Chat | Unit | slugify-channel", function () {
  test("defaults for title", function (assert) {
    assert.strictEqual(slugifyChannel({ title: "Foo bar" }), "foo-bar");
  });

  test("a very long name for the title", function (assert) {
    const string =
      "xAq8l5ca2CtEToeMLe2pEr2VUGQBx3HPlxbkDExKrJHp4f7jCVw9id1EQv1N1lYMRdAIiZNnn94Kr0uU0iiEeVO4XkBVmpW8Mknmd";

    assert.strictEqual(
      slugifyChannel({ title: string }),
      string.toLowerCase().slice(0, -1)
    );
  });

  test("a cyrillic name for the title", function (assert) {
    const string = "Русская литература и фольклор";

    assert.strictEqual(
      slugifyChannel({ title: string }),
      "русская-литература-и-фольклор"
    );
  });

  test("channel has escapedTitle", function (assert) {
    assert.strictEqual(slugifyChannel({ escapedTitle: "Foo bar" }), "foo-bar");
  });

  test("channel has slug and title", function (assert) {
    assert.strictEqual(
      slugifyChannel({ title: "Foo bar", slug: "some-other-thing" }),
      "some-other-thing",
      "slug takes priority"
    );
  });
});
