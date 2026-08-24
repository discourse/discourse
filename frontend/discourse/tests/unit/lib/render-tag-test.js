import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTag from "discourse/lib/render-tag";
import User from "discourse/models/user";

module("Unit | Utility | render-tag", function (hooks) {
  setupTest(hooks);

  test("defaultRenderTag links private message tags by their untranslated name", function (assert) {
    User.resetCurrent(User.create({ id: 1, username: "eviltrout" }));

    assert.strictEqual(
      renderTag(
        {
          id: 1,
          name: "戦略",
          slug: "strategic-access",
          original_name: "strategic_access",
        },
        { isPrivateMessage: true }
      ),
      "<a href='/u/eviltrout/messages/tags/strategic_access'  data-tag-name='strategic_access' class='discourse-tag simple'>戦略</a>"
    );
  });

  test("defaultRenderTag", function (assert) {
    assert.strictEqual(
      renderTag("foo", { description: "foo description" }),
      "<a href='/tag/foo'  data-tag-name='foo' class='discourse-tag simple'>foo</a>",
      "does not expose the description as a tooltip"
    );
  });

  test("defaultRenderTag encodes legacy tag links with periods", function (assert) {
    assert.strictEqual(
      renderTag("node.js"),
      "<a href='/tag/node%2Ejs'  data-tag-name='node.js' class='discourse-tag simple'>node.js</a>"
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
