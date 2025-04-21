import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("color-palettes-row")
export default class ColorPalettesRow extends SelectKitRowComponent {
  @computed("item.colors.[]")
  get palettes() {
    return htmlSafe(
      (this.item.colors || [])
        .filter((color) => color.name !== "secondary")
        .map((color) => `#${escape(color.hex)}`)
        .map(
          (hex) =>
            `<span class="palette" style="background-color:${hex}"></span>`
        )
        .join("")
    );
  }

  @computed("item.colors.[]")
  get backgroundColor() {
    const secondary = (this.item.colors || []).findBy("name", "secondary");

    if (secondary && secondary.hex) {
      return htmlSafe(`background-color:#${escape(secondary.hex)}`);
    } else {
      return "";
    }
  }

  <template>
    <span class="name">
      {{this.label}}
    </span>

    {{#if this.item.colors}}
      <div class="palettes" style={{this.backgroundColor}}>
        {{this.palettes}}
      </div>
    {{/if}}
  </template>
}
