import { setupTest } from "ember-qunit";
import AllowLister from "pretty-text/allow-lister";
import { module, test } from "qunit";

module("Unit | Utility | allowLister", function (hooks) {
  setupTest(hooks);

  test("allowLister", function (assert) {
    const allowLister = new AllowLister();

    assert.true(
      Object.keys(allowLister.getAllowList().tagList).length > 1,
      "has some defaults"
    );

    allowLister.disable("default");

    assert.strictEqual(
      Object.keys(allowLister.getAllowList().tagList).length,
      0,
      "has no defaults if disabled"
    );

    allowLister.allowListFeature("test", [
      "custom.foo",
      "custom.baz",
      "custom[data-*]",
      "custom[data-custom-*=foo]",
      "custom[rel=nofollow]",
    ]);

    allowLister.allowListFeature("test", ["custom[rel=test]"]);

    allowLister.enable("test");

    assert.deepEqual(
      allowLister.getAllowList(),
      {
        tagList: {
          custom: [],
        },
        attrList: {
          custom: {
            class: ["foo", "baz"],
            "data-*": ["*"],
            "data-custom-*": ["foo"],
            rel: ["nofollow", "test"],
          },
        },
      },
      "Expecting a correct allow list"
    );

    allowLister.disable("test");

    assert.deepEqual(
      allowLister.getAllowList(),
      {
        tagList: {},
        attrList: {},
      },
      "Expecting an empty allow list"
    );
  });
});
