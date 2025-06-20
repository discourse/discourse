import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { attributeBindings, classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import DButton from "discourse/components/d-button";

@attributeBindings("style")
@classNames("color-palettes-preview-row")
export default class ColorPalettesRow extends SelectKitRowComponent {
  @computed("item.colors.[]")
  get style() {
    if (!this.item.id) {
      return htmlSafe("");
    }

    let primary;
    let secondary;
    let tertiary;
    let hover;

    for (const color of this.item.colors || []) {
      if (color.name === "primary") {
        primary = color.hex;
      } else if (color.name === "secondary") {
        secondary = color.hex;
      } else if (color.name === "tertiary") {
        tertiary = color.hex;
      } else if (color.name === "hover") {
        hover = color.hex;
      }
    }

    return htmlSafe(`
      --primary: #${escape(primary)};
      --secondary: #${escape(secondary)};
      --d-button-primary-bg-color: #${escape(tertiary)};
      --d-button-primary-text-color: #${escape(secondary)};
      --d-hover: #${escape(hover)};
    `);
  }

  <template>
    <span class="name">
      {{this.label}}
    </span>
    <DButton class="btn-primary" @label="user.choose_palette" />
  </template>
}
