import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTag, {
  defaultRenderTag,
  replaceTagRenderer,
} from "discourse/lib/render-tag";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utility | render-tag", function (hooks) {
  setupTest(hooks);

  test("defaultRenderTag", function (assert) {
    assert.strictEqual(
      renderTag("foo", { description: "foo description" }),
      "<a href='/tag/foo'  data-tag-name=foo class='discourse-tag simple'>foo</a>",
      "does not expose the description as a tooltip"
    );
  });

  test("defaultRenderTag encodes legacy tag links with periods", function (assert) {
    assert.strictEqual(
      renderTag("node.js"),
      "<a href='/tag/node%2Ejs'  data-tag-name=node.js class='discourse-tag simple'>node.js</a>"
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

  module("defaultRenderTag options", function () {
    test("renders another element without a link", function (assert) {
      assert.strictEqual(
        renderTag("foo", { tagName: "span" }),
        "<span data-tag-name=foo class='discourse-tag simple'>foo</span>"
      );
    });

    test("leaves out the link with noHref", function (assert) {
      assert.strictEqual(
        renderTag("foo", { noHref: true }),
        "<a data-tag-name=foo class='discourse-tag simple'>foo</a>"
      );
    });

    test("escapes and lowercases the name", function (assert) {
      assert.strictEqual(
        renderTag("Foo<b>"),
        "<a href='/tag/foo&lt;b&gt;'  data-tag-name=foo&lt;b&gt; class='discourse-tag simple'>Foo&lt;b&gt;</a>"
      );
    });

    test("links a tag object by its slug and id", function (assert) {
      assert.strictEqual(
        renderTag({ id: 7, name: "foo", slug: "foo-slug" }),
        "<a href='/tag/foo-slug/7'  data-tag-name=foo class='discourse-tag simple'>foo</a>"
      );
      assert.strictEqual(
        renderTag({ id: 7, name: "foo" }),
        "<a href='/tag/7-tag/7'  data-tag-name=foo class='discourse-tag simple'>foo</a>",
        "builds a slug without one"
      );
    });

    test("links private message tags to the user's messages", function (assert) {
      const user = logIn(getOwner(this));

      assert.strictEqual(
        renderTag("foo", { isPrivateMessage: true }),
        `<a href='/u/${user.username}/messages/tags/foo'  data-tag-name=foo class='discourse-tag simple'>foo</a>`
      );
      assert.strictEqual(
        renderTag("foo", { pmOnly: true, tagsForUser: "gizmo" }),
        "<a href='/u/gizmo/messages/tags/foo'  data-tag-name=foo class='discourse-tag simple'>foo</a>",
        "uses the given user"
      );
    });

    test("uses the given style, extra class and size", function (assert) {
      assert.strictEqual(
        renderTag("foo", { style: "box", extraClass: "gizmo", size: "large" }),
        "<a href='/tag/foo'  data-tag-name=foo class='discourse-tag box gizmo large'>foo</a>"
      );
    });

    test("adds no style class without a tag style", function (assert) {
      getOwner(this).lookup("service:site-settings").tag_style = "";

      assert.strictEqual(
        renderTag("foo"),
        "<a href='/tag/foo'  data-tag-name=foo class='discourse-tag'>foo</a>"
      );
    });

    test("shows the escaped display name and the count", function (assert) {
      assert.strictEqual(
        renderTag("foo", { displayName: "Foo <b>", count: 3 }),
        "<a href='/tag/foo'  data-tag-name=foo class='discourse-tag simple'>Foo &lt;b&gt;</a> <span class='discourse-tag-count'>x3</span>"
      );
    });

    test("replaceTagRenderer replaces the renderer", function (assert) {
      try {
        replaceTagRenderer((tag, params) => `${tag}:${params.size}`);

        assert.strictEqual(renderTag("foo", { size: "large" }), "foo:large");
      } finally {
        replaceTagRenderer(defaultRenderTag);
      }
    });
  });
});
