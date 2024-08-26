import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import SelectKitComponent, {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("single-select")
@selectKitOptions({
  headerComponent: "select-kit/single-select-header",
})
@pluginApiIdentifiers(["single-select"])
export default class SingleSelect extends SelectKitComponent {
  singleSelect = true;

  @computed("value", "content.[]", "selectKit.noneItem")
  get selectedContent() {
    if (!isEmpty(this.value)) {
      let content;

      const value =
        this.selectKit.options.castInteger && this._isNumeric(this.value)
          ? Number(this.value)
          : this.value;

      if (this.selectKit.valueProperty) {
        content = (this.content || []).findBy(
          this.selectKit.valueProperty,
          value
        );

        return this.selectKit.modifySelection(
          content || this.defaultItem(value, value)
        );
      } else {
        return this.selectKit.modifySelection(
          (this.content || []).filter((c) => c === value)
        );
      }
    } else {
      return this.selectKit.noneItem;
    }
  }
}
