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

  test("renderTag with extraClass", function (assert) {
    const result = renderTag("foo", {
      extraClass: "ins del",
      description: "foo description",
    });

    const div = document.createElement("div");
    div.innerHTML = result;
    const link = div.firstChild;

    assert.true(
      link.classList.contains("discourse-tag"),
      "has discourse-tag class"
    );
    assert.true(link.classList.contains("simple"), "has default simple class");
    assert.true(link.classList.contains("ins"), "has ins class");
    assert.true(link.classList.contains("del"), "has del class");
  });
});
