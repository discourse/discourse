import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | region-input", function (hooks) {
  setupRenderingTest(hooks);

  test("displaying the 'None' region option", async function (assert) {
    this.siteSettings.available_locales = JSON.stringify([
      { name: "English", value: "en" },
    ]);

    await render(hbs`<RegionInput @allowNoneRegion={{true}} />`);
    await selectKit().expand();

    assert
      .dom(".region-input ul li.select-kit-row:first-child")
      .hasText(
        "None",
        "it displays the 'None' option when allowNoneRegion is set to true"
      );
  });

  test("hiding the 'None' region option", async function (assert) {
    this.siteSettings.available_locales = JSON.stringify([
      { name: "English", value: "en" },
    ]);

    await render(hbs`<RegionInput @allowNoneRegion={{false}} />`);
    await selectKit().expand();

    assert
      .dom(".region-input ul li.select-kit-row:first-child")
      .hasText(
        "Argentina",
        "it does not display the 'None' option when allowNoneRegion is set to false"
      );
  });
});
