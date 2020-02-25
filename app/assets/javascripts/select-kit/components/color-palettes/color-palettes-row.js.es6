import { escapeExpression } from "discourse/lib/utilities";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { computed } from "@ember/object";

export default SelectKitRowComponent.extend({
  classNames: ["color-palettes-row"],

  layoutName:
    "select-kit/templates/components/color-palettes/color-palettes-row",

  palettes: computed("item.colors.[]", function() {
    return (this.item.colors || [])
      .map(color => `#${escapeExpression(color.hex)}`)
      .map(
        hex => `<span class="palette" style="background-color:${hex}"></span>`
      )
      .join("")
      .htmlSafe();
  })
});
