import { module, test } from "qunit";
import AllowLister from "pretty-text/allow-lister";

module("Unit | Utility | allowLister", function () {
  test("allowLister", function (assert) {
    const allowLister = new AllowLister();

    assert.ok(
      Object.keys(allowLister.getAllowList().tagList).length > 1,
      "should have some defaults"
    );

    allowLister.disable("default");

    assert.ok(
      Object.keys(allowLister.getAllowList().tagList).length === 0,
      "should have no defaults if disabled"
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
