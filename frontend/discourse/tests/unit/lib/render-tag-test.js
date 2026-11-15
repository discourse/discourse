import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import renderTag from "discourse/lib/render-tag";
import User from "discourse/models/user";

module("Unit | Utility | render-tag", function (hooks) {
  setupTest(hooks);

  test("defaultRenderTag", function (assert) {
    assert.strictEqual(
      renderTag("foo", { description: "foo description" }),
      `<a href='/tag/foo'  data-tag-name="foo" class='discourse-tag simple'>foo</a>`,
      "does not expose the description as a tooltip"
    );
  });

  test("defaultRenderTag encodes legacy tag links with periods", function (assert) {
    assert.strictEqual(
      renderTag("node.js"),
      `<a href='/tag/node%2Ejs'  data-tag-name="node.js" class='discourse-tag simple'>node.js</a>`
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

  test("renderTag keeps tag names inside data-tag-name", function (assert) {
    const name = `bug" onmouseover="alert(1)`;
    const div = document.createElement("div");

    div.innerHTML = renderTag({ id: 42, name, slug: "bug" });

    assert
      .dom("a", div)
      .hasAttribute("data-tag-name", name, "preserves the complete tag name")
      .doesNotHaveAttribute("onmouseover", "adds no event handler");
  });

  test("renderTag keeps slug content inside the href attribute", function (assert) {
    const slug = `../foo\\bar?x#%' onclick='alert(1)' title='"<>&amp;`;
    const div = document.createElement("div");

    div.innerHTML = renderTag({ id: 42, name: "foo", slug });

    assert.dom(div).hasText("foo", "preserves the tag label");
    assert.dom("a", div).exists({ count: 1 }, "renders one link");
    assert
      .dom("a", div)
      .hasAttribute(
        "href",
        `/tag/..%2Ffoo%5Cbar%3Fx%23%25'%20onclick%3D'alert(1)'%20title%3D'%22%3C%3E%26amp%3B/42`,
        "encodes the complete slug as URL data"
      );
    assert
      .dom("a", div)
      .doesNotHaveAttribute("onclick", "does not introduce an event handler");
    assert
      .dom("a", div)
      .doesNotHaveAttribute("title", "does not introduce another attribute");
  });

  test("renderTag preserves object tag destinations", function (assert) {
    const div = document.createElement("div");

    div.innerHTML = renderTag({ id: 42, name: "Foo", slug: "custom-slug" });

    assert
      .dom("a", div)
      .hasAttribute("href", "/tag/custom-slug/42", "uses the custom slug");
    assert.dom("a", div).hasText("Foo", "preserves the visible name");

    div.innerHTML = renderTag({ id: 42, slug: "" });

    assert
      .dom("a", div)
      .hasAttribute("href", "/tag/42-tag/42", "uses the fallback slug");
  });

  test("renderTag escapes legacy URLs once", function (assert) {
    const div = document.createElement("div");

    div.innerHTML = renderTag("Rock&Roll's");

    assert
      .dom("a", div)
      .hasAttribute(
        "href",
        "/tag/rock&roll's",
        "preserves legacy URL characters"
      );
    assert.dom("a", div).hasText("Rock&Roll's", "preserves the visible name");
  });

  test("renderTag escapes message tag URLs once", function (assert) {
    sinon.stub(User, "current").returns({ username: "alice" });
    const div = document.createElement("div");

    div.innerHTML = renderTag("Rock&Roll's", { isPrivateMessage: true });

    assert
      .dom("a", div)
      .hasAttribute(
        "href",
        "/u/alice/messages/tags/rock&roll's",
        "preserves the message tag destination"
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
