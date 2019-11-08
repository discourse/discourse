import { alias, and } from "@ember/object/computed";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

export default SelectKitHeaderComponent.extend({
  layoutName: "select-kit/templates/components/combo-box/combo-box-header",
  classNames: "combo-box-header",

  clearable: alias("options.clearable"),
  caretUpIcon: alias("options.caretUpIcon"),
  caretDownIcon: alias("options.caretDownIcon"),
  shouldDisplayClearableButton: and(
    "clearable",
    "computedContent.hasSelection"
  )
});
