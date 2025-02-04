import { computed } from "@ember/object";
import { and, reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import SingleSelectHeaderComponent from "select-kit/components/select-kit/single-select-header";

@classNames("combo-box-header")
export default class ComboBoxHeader extends SingleSelectHeaderComponent {
  @reads("selectKit.options.clearable") clearable;
  @reads("selectKit.options.caretUpIcon") caretUpIcon;
  @reads("selectKit.options.caretDownIcon") caretDownIcon;
  @and("clearable", "value") shouldDisplayClearableButton;

  @computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon")
  get caretIcon() {
    return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
  }
}
