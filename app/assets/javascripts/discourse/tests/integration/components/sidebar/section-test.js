import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | sidebar | section", function (hooks) {
  setupRenderingTest(hooks);

  test("default displaySection value for section", async function (assert) {
    const template = hbs`
      <Sidebar::Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}} />`;

    this.headerActions = [];
    await render(template);

    assert
      .dom(".sidebar-section-wrapper")
      .exists("section is displayed by default if no display arg is provided");
  });

  test("displaySection is dynamic based on argument", async function (assert) {
    const template = hbs`
      <Sidebar::Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @displaySection={{this.displaySection}}/>`;

    this.displaySection = false;
    this.headerActions = [];
    await render(template);

    assert
      .dom(".sidebar-section-wrapper")
      .doesNotExist("section is not displayed");

    this.set("displaySection", true);
    assert.dom(".sidebar-section-wrapper").exists("section is displayed");
  });

  test("can expand and collapse content when section is collapsible", async function (assert) {
    const template = hbs`
      <Sidebar::Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @collapsable={{true}} />`;

    this.headerActions = [];
    await render(template);

    assert.dom(".sidebar-section-content").exists("shows content by default");

    await click(".sidebar-section-header-caret");

    assert
      .dom(".sidebar-section-content")
      .doesNotExist("does not show content after collapsing");
  });
});
