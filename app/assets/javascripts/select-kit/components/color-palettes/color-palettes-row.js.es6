import { escapeExpression } from "discourse/lib/utilities";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import discourseComputed from "discourse-common/utils/decorators";

export default SelectKitRowComponent.extend({
  layoutName:
    "select-kit/templates/components/color-palettes/color-palettes-row",
  classNames: "color-palettes-row",

  @discourseComputed("computedContent.originalContent.colors")
  colors(colors) {
    return (colors || []).map(color => `#${escapeExpression(color.hex)}`);
  }
});
