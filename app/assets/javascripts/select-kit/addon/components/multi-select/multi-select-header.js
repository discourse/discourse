import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

@tagName("summary")
@classNames("multi-select-header")
@attributeBindings("ariaLabel:aria-label")
export default class MultiSelectHeader extends SelectKitHeaderComponent {
  @reads("selectKit.options.caretUpIcon") caretUpIcon;
  @reads("selectKit.options.caretDownIcon") caretDownIcon;
  @reads("selectKit.options.headerAriaLabel") ariaLabel;

  @computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon")
  get caretIcon() {
    return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
  }
}
