import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Section from "discourse/components/sidebar/section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | sidebar | section", function (hooks) {
  setupRenderingTest(hooks);

  test("default displaySection value for section", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
      />
    </template>;

    this.headerActions = [];
    await render(template);

    assert.ok(
      exists(".sidebar-section-wrapper"),
      "section is displayed by default if no display arg is provided"
    );
  });

  test("displaySection is dynamic based on argument", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @displaySection={{this.displaySection}}
      />
    </template>;

    this.displaySection = false;
    this.headerActions = [];
    await render(template);

    assert.notOk(
      exists(".sidebar-section-wrapper"),
      "section is not displayed"
    );

    this.set("displaySection", true);
    assert.ok(exists(".sidebar-section-wrapper"), "section is displayed");
  });

  test("can expand and collapse content when section is collapsible", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @collapsable={{true}}
      />
    </template>;

    this.headerActions = [];
    await render(template);

    assert.ok(exists(".sidebar-section-content"), "shows content by default");

    await click(".sidebar-section-header-caret");

    assert.notOk(
      exists(".sidebar-section-content"),
      "does not show content after collapsing"
    );
  });
});
