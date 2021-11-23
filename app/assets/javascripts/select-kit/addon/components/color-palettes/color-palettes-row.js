import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/color-palettes/color-palettes-row";

export default SelectKitRowComponent.extend({
  classNames: ["color-palettes-row"],
  layout,

  palettes: computed("item.colors.[]", function () {
    return (this.item.colors || [])
      .filter((color) => color.name !== "secondary")
      .map((color) => `#${escape(color.hex)}`)
      .map(
        (hex) => `<span class="palette" style="background-color:${hex}"></span>`
      )
      .join("")
      .htmlSafe();
  }),

  backgroundColor: computed("item.colors.[]", function () {
    const secondary = (this.item.colors || []).findBy("name", "secondary");

    if (secondary && secondary.hex) {
      return `background-color:#${escape(secondary.hex)}`.htmlSafe();
    } else {
      return "";
    }
  }),
});
