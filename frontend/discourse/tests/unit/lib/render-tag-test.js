import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTag from "discourse/lib/render-tag";

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

  test("renders stable IDs alongside source or localized tag names", function (assert) {
    for (const name of ["cat", "猫"]) {
      const div = document.createElement("div");
      div.innerHTML = renderTag({ id: 123, name, slug: "cat" });

      assert
        .dom(".discourse-tag", div)
        .hasAttribute("data-tag-id", "123")
        .hasAttribute("data-tag-name", name)
        .hasAttribute("href", "/tag/cat/123")
        .hasText(name);
    }
  });

  test("includes IDs when rendering tags without links", function (assert) {
    for (const params of [{ noHref: true }, { tagName: "span" }]) {
      const div = document.createElement("div");
      div.innerHTML = renderTag({ id: 123, name: "猫", slug: "cat" }, params);

      assert
        .dom(".discourse-tag", div)
        .hasAttribute("data-tag-id", "123")
        .hasAttribute("data-tag-name", "猫")
        .doesNotHaveAttribute("href")
        .hasText("猫");
    }
  });

  test("accepts an explicit ID without changing a name-only tag link", function (assert) {
    const div = document.createElement("div");
    div.innerHTML = renderTag("cat", { tagId: 123 });

    assert
      .dom(".discourse-tag", div)
      .hasAttribute("data-tag-id", "123")
      .hasAttribute("data-tag-name", "cat")
      .hasAttribute("href", "/tag/cat")
      .hasText("cat");
  });

  test("does not add an ID for tag objects without one", function (assert) {
    const div = document.createElement("div");
    div.innerHTML = renderTag({ name: "cat" });

    assert
      .dom(".discourse-tag", div)
      .doesNotHaveAttribute("data-tag-id")
      .hasAttribute("data-tag-name", "cat")
      .hasAttribute("href", "/tag/cat")
      .hasText("cat");
  });

  test("escapes the ID attribute", function (assert) {
    const id = "123' onclick='alert(1)";
    const div = document.createElement("div");
    div.innerHTML = renderTag({ id, name: "cat" }, { noHref: true });

    assert
      .dom(".discourse-tag", div)
      .hasAttribute("data-tag-id", id)
      .doesNotHaveAttribute("onclick");
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
