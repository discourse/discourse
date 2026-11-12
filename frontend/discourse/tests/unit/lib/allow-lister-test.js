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

  test("allowLister reads its options", function (assert) {
    const allowLister = new AllowLister({
      allowedHrefSchemes: ["tel"],
      allowedIframes: ["https://example.com/"],
      features: { gadget: true, gizmo: false },
    });
    allowLister.disable("default");
    allowLister.allowListFeature("gadget", "gadget-tag");
    allowLister.allowListFeature("gizmo", "gizmo-tag");

    assert.deepEqual(allowLister.getAllowedHrefSchemes(), ["tel"]);
    assert.deepEqual(allowLister.getAllowedIframes(), ["https://example.com/"]);
    assert.deepEqual(
      allowLister.getAllowList().tagList,
      { "gadget-tag": [] },
      "enables only the features set to true"
    );
  });

  test("allowLister defaults its options", function (assert) {
    const allowLister = new AllowLister();

    assert.deepEqual(allowLister.getAllowedHrefSchemes(), []);
    assert.deepEqual(allowLister.getAllowedIframes(), []);
    assert.deepEqual(allowLister.getCustom(), []);
  });

  test("allowLister collects custom rules", function (assert) {
    const allowLister = new AllowLister();
    const rule = () => true;

    allowLister.allowListFeature("default", { custom: rule });
    allowLister.allowListFeature("gadget", { custom: () => false });
    allowLister.enable("default");

    assert.deepEqual(
      allowLister.getCustom(),
      [rule],
      "skips disabled features"
    );
    assert.false(
      "undefined" in allowLister.getAllowList().tagList,
      "adds no tags for a custom rule"
    );
  });
});
