import { module, test } from "qunit";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

module("Discourse Chat | Unit | slugify-channel", function () {
  test("defaults", function (assert) {
    assert.equal(slugifyChannel("Foo bar"), "foo-bar");
  });

  test("a very long name", function (assert) {
    const string =
      "xAq8l5ca2CtEToeMLe2pEr2VUGQBx3HPlxbkDExKrJHp4f7jCVw9id1EQv1N1lYMRdAIiZNnn94Kr0uU0iiEeVO4XkBVmpW8Mknmd";

    assert.equal(slugifyChannel(string), string.toLowerCase().slice(0, -1));
  });

  test("a cyrillic name", function (assert) {
    const string = "Русская литература и фольклор";

    assert.equal(slugifyChannel(string), "русская-литература-и-фольклор");
  });
});
