import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, set } from "@ember/object";
import { Choice } from "discourse/static/wizard/models/wizard";
import { i18n } from "discourse-i18n";
import ColorPalettes from "select-kit/components/color-palettes";
import ComboBox from "select-kit/components/combo-box";
import FontSelector from "select-kit/components/font-selector";
import HomepageStyleSelector from "select-kit/components/homepage-style-selector";

export default class Dropdown extends Component {
  constructor() {
    super(...arguments);

    if (this.args.field.id === "color_scheme") {
      for (let choice of this.args.field.choices) {
        if (choice?.data?.colors) {
          set(choice, "colors", choice.data.colors);
        }
      }
    }

    if (this.args.field.id === "body_font") {
      for (let choice of this.args.field.choices) {
        set(choice, "classNames", `body-font-${choice.id.replace(/_/g, "-")}`);
      }
    }

    if (this.args.field.id === "heading_font") {
      for (let choice of this.args.field.choices) {
        set(
          choice,
          "classNames",
          `heading-font-${choice.id.replace(/_/g, "-")}`
        );
      }
    }

    if (this.args.field.id === "homepage_style") {
      // These are the 3 supported options for the wizard, but admins can
      // configure other options too. See also Wizard::Builder
      if (
        !["hot", "latest", "category_boxes"].includes(this.args.field.value)
      ) {
        let type, landingPage;
        if (
          this.args.field.value.includes("category") ||
          this.args.field.value.includes("categories")
        ) {
          type = i18n("wizard.homepage_choices.style_type.categories");
          landingPage = i18n(`wizard.top_menu_items.categories`);
        } else {
          type = i18n(`wizard.homepage_choices.style_type.topics`);
          landingPage = i18n(`wizard.top_menu_items.${this.args.field.value}`);
        }

        this.args.field.choices.push(
          new Choice({
            id: this.args.field.value,
            label: i18n("wizard.homepage_choices.custom.label"),
            description: i18n("wizard.homepage_choices.custom.description", {
              type,
              landingPage: landingPage.toLowerCase(),
            }),
          })
        );
      }
    }
  }

  get component() {
    switch (this.args.field.id) {
      case "color_scheme":
        return ColorPalettes;
      case "body_font":
      case "heading_font":
        return FontSelector;
      case "homepage_style":
        return HomepageStyleSelector;
      default:
        return ComboBox;
    }
  }

  keyPress(event) {
    event.stopPropagation();
  }

  @action
  onChangeValue(value) {
    this.set("field.value", value);
  }

  <template>
    {{component
      this.component
      class="wizard-container__dropdown"
      value=@field.value
      content=@field.choices
      nameProperty="label"
      tabindex="9"
      onChange=this.onChangeValug
      options=(hash translatedNone=false)
    }}
  </template>
}
