import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

function containsExactly(assert, expectation, actual, message) {
  assert.deepEqual(
    Array.from(expectation).sort(),
    Array.from(actual).sort(),
    message
  );
}

module("Integration | Component | sidebar | section-link", function (hooks) {
  setupRenderingTest(hooks);

  test("default class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="Test Meta" @route="discovery.latest" />`;

    await render(template);

    containsExactly(
      assert,
      query("a").classList,
      ["ember-view", "sidebar-row", "sidebar-section-link"],
      "has the right class attribute for the link"
    );
  });

  test("custom class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="Test Meta" @route="discovery.latest" @linkClass="123 abc" />`;

    await render(template);

    containsExactly(
      assert,
      query("a").classList,
      ["123", "abc", "ember-view", "sidebar-row", "sidebar-section-link"],
      "has the right class attribute for the link"
    );
  });

  test("target attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="test" @href="https://discourse.org" />`;
    await render(template);

    assert.dom("a").hasAttribute("target", "_self");
  });

  test("target attribute for link when user set external links in new tab", async function (assert) {
    this.currentUser.user_option.external_links_in_new_tab = true;
    const template = hbs`<Sidebar::SectionLink @linkName="test" @href="https://discourse.org" />`;
    await render(template);

    assert.dom("a").hasAttribute("target", "_blank");
  });
});
