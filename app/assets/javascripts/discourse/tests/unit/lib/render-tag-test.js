import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTag from "discourse/lib/render-tag";

module("Unit | Utility | render-tag", function (hooks) {
  setupTest(hooks);

  test("defaultRenderTag", function (assert) {
    assert.strictEqual(
      renderTag("foo", { description: "foo description" }),
      "<a href='/tag/foo'  data-tag-name=foo title=\"foo description\"  class='discourse-tag simple'>foo</a>",
      "formats tag as link with plain description in hover"
    );

    assert.strictEqual(
      renderTag("foo", {
        description: 'foo description <a href="localhost">link</a>',
      }),
      "<a href='/tag/foo'  data-tag-name=foo title=\"foo description link\"  class='discourse-tag simple'>foo</a>",
      "removes any html tags from description"
    );
  });
});
