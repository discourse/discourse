import WhiteLister from "pretty-text/white-lister";

QUnit.module("lib:whiteLister");

QUnit.test("whiteLister", assert => {
  const whiteLister = new WhiteLister();

  assert.ok(
    Object.keys(whiteLister.getWhiteList().tagList).length > 1,
    "should have some defaults"
  );

  whiteLister.disable("default");

  assert.ok(
    Object.keys(whiteLister.getWhiteList().tagList).length === 0,
    "should have no defaults if disabled"
  );

  whiteLister.whiteListFeature("test", [
    "custom.foo",
    "custom.baz",
    "custom[data-*]",
    "custom[rel=nofollow]"
  ]);

  whiteLister.whiteListFeature("test", ["custom[rel=test]"]);

  whiteLister.enable("test");

  assert.deepEqual(
    whiteLister.getWhiteList(),
    {
      tagList: {
        custom: []
      },
      attrList: {
        custom: {
          class: ["foo", "baz"],
          "data-*": ["*"],
          rel: ["nofollow", "test"]
        }
      }
    },
    "Expecting a correct white list"
  );

  whiteLister.disable("test");

  assert.deepEqual(
    whiteLister.getWhiteList(),
    {
      tagList: {},
      attrList: {}
    },
    "Expecting an empty white list"
  );
});
