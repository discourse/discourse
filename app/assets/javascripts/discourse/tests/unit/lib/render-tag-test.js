import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTag, { defaultRenderTag } from "discourse/lib/render-tag";

module("Unit | Utility | render-tag", function (hooks) {
  setupTest(hooks);

  test("defaultRenderTag", function (assert) {
    assert.strictEqual(
      renderTag("foo", { description: "foo description" }),
      '<a href="/tag/foo" data-tag-name="foo" title="foo description" class="discourse-tag simple">foo</a>',
      "formats tag as link with plain description in hover"
    );

    assert.strictEqual(
      renderTag("foo", {
        description: 'foo description <a href="localhost">link</a>',
      }),
      '<a href="/tag/foo" data-tag-name="foo" title="foo description link" class="discourse-tag simple">foo</a>',
      "removes any html tags from description"
    );

    assert.strictEqual(
      renderTag("foo", { noHref: true }),
      '<a data-tag-name="foo" class="discourse-tag simple">foo</a>',
      "allows no href"
    );

    assert.strictEqual(
      renderTag("foo", {
        tagGroups: ["group1", "group2"],
      }),
      '<a href="/tag/foo" data-tag-name="foo" data-tag-groups="group1,group2" class="discourse-tag simple">foo</a>',
      "adds the tag-groups to data"
    );

    assert.strictEqual(
      defaultRenderTag(
        "foo",
        {},
        {
          extraClass: "classname1 classname2",
          contentFn: (c) => `Tag - ${c}`,
          attrs: {
            "data-foo": "bar",
          },
        }
      ),
      '<a href="/tag/foo" data-tag-name="foo" class="discourse-tag simple classname1 classname2" data-foo="bar">Tag - foo</a>',
      "works fine with extra parameters"
    );
  });
});
