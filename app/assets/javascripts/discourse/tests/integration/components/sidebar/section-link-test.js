import { module, test } from "qunit";

import { hbs } from "ember-cli-htmlbars";
import { render } from "@ember/test-helpers";

import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | sidebar | section-link", function (hooks) {
  setupRenderingTest(hooks);

  test("default class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="test" @route="discovery.latest" />`;

    await render(template);

    assert.strictEqual(
      query("a").className,
      "sidebar-section-link sidebar-section-link-test sidebar-row ember-view",
      "has the right class attribute for the link"
    );
  });

  test("custom class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="test" @route="discovery.latest" @class="123 abc" />`;

    await render(template);

    assert.strictEqual(
      query("a").className,
      "sidebar-section-link sidebar-section-link-test sidebar-row 123 abc ember-view",
      "has the right class attribute for the link"
    );
  });
});
