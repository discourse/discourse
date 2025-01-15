import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Dropdown from "discourse/static/wizard/components/fields/dropdown";
import { Choice, Field } from "discourse/static/wizard/models/wizard";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function buildFontChoices() {
  return [
    {
      id: "arial",
      label: "Arial",
      classNames: "body-font-arial",
    },
    {
      id: "helvetica",
      label: "Helvetica",
      classNames: "body-font-helvetica",
    },
    {
      id: "lato",
      label: "Lato",
      classNames: "body-font-lato",
    },
    {
      id: "montserrat",
      label: "Montserrat",
      classNames: "body-font-montserrat",
    },
    {
      id: "noto_sans",
      label: "NotoSans",
      classNames: "body-font-noto-sans",
    },
    {
      id: "roboto",
      label: "Roboto",
      classNames: "body-font-roboto",
    },
    {
      id: "ubuntu",
      label: "Ubuntu",
      classNames: "body-font-ubuntu",
    },
  ];
}

module(
  "Integration | Component | Wizard | Fields | Dropdown",
  function (hooks) {
    setupRenderingTest(hooks);

    test("color_scheme field sets colors data on each field choice to render palettes in dropdown", async function (assert) {
      const lightColors = [
        {
          name: "primary",
          hex: "222222",
        },
        {
          name: "secondary",
          hex: "ffffff",
        },
        {
          name: "tertiary",
          hex: "0088cc",
        },
        {
          name: "quaternary",
          hex: "e45735",
        },
        {
          name: "header_background",
          hex: "ffffff",
        },
        {
          name: "header_primary",
          hex: "333333",
        },
        {
          name: "highlight",
          hex: "ffff4d",
        },
        {
          name: "selected",
          hex: "d1f0ff",
        },
        {
          name: "hover",
          hex: "f2f2f2",
        },
        {
          name: "danger",
          hex: "c80001",
        },
        {
          name: "success",
          hex: "009900",
        },
        {
          name: "love",
          hex: "fa6c8d",
        },
      ];

      const darkColors = [
        {
          name: "primary",
          hex: "dddddd",
        },
        {
          name: "secondary",
          hex: "222222",
        },
        {
          name: "tertiary",
          hex: "099dd7",
        },
        {
          name: "quaternary",
          hex: "c14924",
        },
        {
          name: "header_background",
          hex: "111111",
        },
        {
          name: "header_primary",
          hex: "dddddd",
        },
        {
          name: "highlight",
          hex: "a87137",
        },
        {
          name: "selected",
          hex: "052e3d",
        },
        {
          name: "hover",
          hex: "313131",
        },
        {
          name: "danger",
          hex: "e45735",
        },
        {
          name: "success",
          hex: "1ca551",
        },
        {
          name: "love",
          hex: "fa6c8d",
        },
      ];

      const field = new Field({
        type: "dropdown",
        id: "color_scheme",
        label: "Color palette",
        choices: [
          new Choice({
            id: "light",
            label: "Light",
            data: { colors: lightColors },
          }),
          new Choice({
            id: "dark",
            label: "Dark",
            data: { colors: darkColors },
          }),
        ],
      });

      await render(<template><Dropdown @field={{field}} /></template>);
      const colorPalettesSelector = selectKit(
        ".wizard-container__dropdown.color-palettes"
      );
      await colorPalettesSelector.expand();

      lightColors
        .reject((colorDef) => colorDef.name === "secondary")
        .forEach((colorDef) => {
          assert
            .dom(
              `.palettes .palette[style*='background-color:#${colorDef.hex}']`,
              colorPalettesSelector.rowByValue("light").el()
            )
            .exists();
        });

      darkColors
        .reject((colorDef) => colorDef.name === "secondary")
        .forEach((colorDef) => {
          assert
            .dom(
              `.palettes .palette[style*='background-color:#${colorDef.hex}']`,
              colorPalettesSelector.rowByValue("dark").el()
            )
            .exists();
        });
    });

    test("body_font sets body-font-X classNames on each field choice", async function (assert) {
      const fontChoices = buildFontChoices();

      const field = new Field({
        type: "dropdown",
        id: "body_font",
        label: "Body font",
        choices: fontChoices.map((choice) => new Choice(choice)),
      });

      await render(<template><Dropdown @field={{field}} /></template>);
      const fontSelector = selectKit(
        ".wizard-container__dropdown.font-selector"
      );
      await fontSelector.expand();

      fontChoices.forEach((choice) => {
        assert.true(
          fontSelector
            .rowByValue(choice.id)
            .hasClass(`body-font-${choice.id.replace("_", "-")}`),
          `has body-font-${choice.id} CSS class`
        );
      });
    });

    test("heading_font sets heading-font-x classNames on each field choice", async function (assert) {
      const fontChoices = buildFontChoices();

      const field = new Field({
        type: "dropdown",
        id: "heading_font",
        label: "heading font",
        choices: fontChoices.map((choice) => new Choice(choice)),
      });

      await render(<template><Dropdown @field={{field}} /></template>);
      const fontSelector = selectKit(
        ".wizard-container__dropdown.font-selector"
      );
      await fontSelector.expand();

      fontChoices.forEach((choice) => {
        assert.true(
          fontSelector
            .rowByValue(choice.id)
            .hasClass(`heading-font-${choice.id.replace("_", "-")}`),
          `has heading-font-${choice.id} CSS class`
        );
      });
    });

    test("homepage_style shows the 3 main options by default (hot, latest, category_boxes)", async function (assert) {
      const field = new Field({
        type: "dropdown",
        id: "homepage_style",
        label: "homepage style",
        value: "latest",
        choices: [
          { id: "latest", description: "latest stuff" },
          { id: "hot", description: "hot stuff" },
          { id: "category_boxes", description: "category boxes" },
        ],
      });

      await render(<template><Dropdown @field={{field}} /></template>);
      const homepageStyleSelector = selectKit(
        ".wizard-container__dropdown.homepage-style-selector"
      );
      await homepageStyleSelector.expand();
      assert.strictEqual(
        homepageStyleSelector.displayedContent().length,
        3,
        "has 3 options by default"
      );
    });

    test("homepage_style shows an additional custom option for less common setting configurations", async function (assert) {
      const field = new Field({
        type: "dropdown",
        id: "homepage_style",
        label: "homepage style",
        value: "categories_and_latest_topics_created_date",
        choices: [
          { id: "latest", description: "latest stuff" },
          { id: "hot", description: "hot stuff" },
          { id: "category_boxes", description: "category boxes" },
        ],
      });

      await render(<template><Dropdown @field={{field}} /></template>);
      const homepageStyleSelector = selectKit(
        ".wizard-container__dropdown.homepage-style-selector"
      );
      await homepageStyleSelector.expand();
      assert.strictEqual(
        homepageStyleSelector.selectedRow().value(),
        "categories_and_latest_topics_created_date"
      );
      assert.strictEqual(
        homepageStyleSelector.selectedRow().label(),
        i18n("wizard.homepage_choices.custom.label")
      );
      assert.strictEqual(
        homepageStyleSelector.selectedRow().description(),
        i18n("wizard.homepage_choices.custom.description", {
          type: i18n("wizard.homepage_choices.style_type.categories"),
          landingPage: i18n(`wizard.top_menu_items.categories`).toLowerCase(),
        })
      );

      field.value = "top";
      await render(<template><Dropdown @field={{field}} /></template>);
      await homepageStyleSelector.expand();
      assert.strictEqual(homepageStyleSelector.selectedRow().value(), "top");
      assert.strictEqual(
        homepageStyleSelector.selectedRow().label(),
        i18n("wizard.homepage_choices.custom.label")
      );
      assert.strictEqual(
        homepageStyleSelector.selectedRow().description(),
        i18n("wizard.homepage_choices.custom.description", {
          type: i18n("wizard.homepage_choices.style_type.topics"),
          landingPage: i18n(`wizard.top_menu_items.top`).toLowerCase(),
        })
      );
    });
  }
);
