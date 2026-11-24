import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import FieldsSelectExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/select/content/fields";
import HeldMarkSelectExample, {
  markSiteDefault,
} from "discourse/plugins/styleguide/discourse/components/examples/molecules/select/content/held-mark";
import SettingsOverFieldsSelectExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/select/content/settings-over-fields";

const t = (key, options) => i18n(`styleguide.sections.select.${key}`, options);

const row = (value) => `[role='option'][data-value='${value}']`;

module(
  "Styleguide | Integration | select presentation examples",
  function (hooks) {
    setupRenderingTest(hooks);

    test("fields draw each order's name, glyph and summary", async function (assert) {
      await render(<template><FieldsSelectExample /></template>);
      await dSelect().open();

      assert.dom(row("top")).includesText(t("sort_orders.top"));
      assert
        .dom(`${row("top")} .d-select__option-icon`)
        .hasClass("d-icon-arrow-up", "the icon field draws the glyph");
      assert
        .dom(`${row("top")} .d-select__option-description`)
        .hasText(
          t("sort_orders.top_summary"),
          "the description field draws the line"
        );

      await dSelect().select("replies");
      assert
        .dom(".d-select__trigger .d-icon-far-comment")
        .exists("the trigger draws the held order's glyph");
    });

    test("settings win over the fields for the recommended order only", async function (assert) {
      await render(<template><SettingsOverFieldsSelectExample /></template>);
      await dSelect().open();

      assert
        .dom(row("top"))
        .includesText(
          t("content.settings_recommended", { name: t("sort_orders.top") })
        );
      assert
        .dom(`${row("top")} .d-select__option-icon`)
        .hasClass("d-icon-star", "the icon setting replaces the field's glyph");
      assert
        .dom(`${row("top")} .d-select__option-description`)
        .hasText(
          t("content.settings_recommended_description"),
          "the description setting replaces the summary"
        );
      assert
        .dom(`${row("latest")} .d-select__option-icon`)
        .hasClass("d-icon-far-clock", "other orders keep their fields");
      assert
        .dom(`${row("latest")} .d-select__option-description`)
        .hasText(t("sort_orders.latest_summary"));
    });

    test("a plugin's mark reaches the closed trigger and survives a search", async function (assert) {
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) => {
          markSiteDefault(value);
        })
      );
      await render(<template><HeldMarkSelectExample /></template>);

      assert
        .dom(".d-select__trigger .d-icon-star")
        .exists("the held default carries the mark before the list opens");

      await dSelect().search("top");
      assert.dom(row("latest")).doesNotExist("the search filters Latest out");
      assert
        .dom(".d-select__trigger .d-icon-star")
        .exists("the trigger keeps the mark while searching");

      await dSelect().select("top");
      assert
        .dom(".d-select__trigger .d-icon-star")
        .doesNotExist("an unmarked order shows no mark");
    });
  }
);
