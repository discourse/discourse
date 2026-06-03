import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import getURL, { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// These templates deliberately use raw href values with no manual `getURL`.
// The auto-get-url build transform should wrap them so the subfolder base path
// ("/forum" here) is present in the rendered attribute.
module("Integration | lib | auto-get-url transform", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    setPrefix("/forum");
  });

  test("prefixes a raw href binding", async function (assert) {
    this.url = "/t/slug/123";
    await render(
      <template>
        <a href={{this.url}}>link</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "/forum/t/slug/123");
  });

  test("prefixes a raw href string literal", async function (assert) {
    await render(
      <template>
        <a href="/about">about</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "/forum/about");
  });

  test("prefixes a literal+binding concat href", async function (assert) {
    this.id = 123;
    await render(
      <template>
        <a href="/t/{{this.id}}">topic</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "/forum/t/123");
  });

  test("does not double-prefix an already-wrapped href", async function (assert) {
    await render(
      <template>
        <a href={{getURL "/already"}}>x</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "/forum/already");
  });

  test("omits the attribute for a nullish binding", async function (assert) {
    this.url = null;
    await render(
      <template>
        <a href={{this.url}}>x</a>
      </template>
    );
    assert.dom("a").doesNotHaveAttribute("href");
  });

  test("keeps an empty string binding empty", async function (assert) {
    this.url = "";
    await render(
      <template>
        <a href={{this.url}}>x</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "");
  });

  test("leaves external urls untouched", async function (assert) {
    await render(
      <template>
        <a href="https://example.com/x">ext</a>
      </template>
    );
    assert.dom("a").hasAttribute("href", "https://example.com/x");
  });

  test("leaves anchors and mailto untouched", async function (assert) {
    await render(
      <template>
        <a id="anchor" href="#section">anchor</a>
        <a id="mail" href="mailto:a@b.com">mail</a>
      </template>
    );
    assert.dom("#anchor").hasAttribute("href", "#section");
    assert.dom("#mail").hasAttribute("href", "mailto:a@b.com");
  });

  test("leaves img src untouched while the scope is a[href] only", async function (assert) {
    this.src = "/images/logo.png";
    await render(<template><img src={{this.src}} alt="logo" /></template>);
    assert.dom("img").hasAttribute("src", "/images/logo.png");
  });

  test("does not prefix non-url attributes", async function (assert) {
    this.url = "/t/slug/123";
    await render(
      <template>
        <a data-url={{this.url}}>x</a>
      </template>
    );
    assert.dom("a").hasAttribute("data-url", "/t/slug/123");
  });
});
