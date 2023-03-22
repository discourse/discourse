import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";

export default SelectKitRowComponent.extend({
  classNames: ["color-palettes-row"],

  palettes: computed("item.colors.[]", function () {
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
  }),

  backgroundColor: computed("item.colors.[]", function () {
    const secondary = (this.item.colors || []).findBy("name", "secondary");

    if (secondary && secondary.hex) {
      return htmlSafe(`background-color:#${escape(secondary.hex)}`);
    } else {
      return "";
    }
  })
});
