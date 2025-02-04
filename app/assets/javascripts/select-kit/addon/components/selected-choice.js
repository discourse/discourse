import Component from "@ember/component";
import { computed } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { tagName } from "@ember-decorators/component";
import UtilsMixin from "select-kit/mixins/utils";

@tagName("")
export default class SelectedChoice extends Component.extend(UtilsMixin) {
  item = null;
  selectKit = null;
  extraClass = null;
  id = null;

  init() {
    super.init(...arguments);

    this.set("id", guidFor(this));
  }

  @computed("item")
  get itemValue() {
    return this.getValue(this.item);
  }

  @computed("item")
  get itemName() {
    return this.getName(this.item);
  }

  @computed("item")
  get mandatoryValuesArray() {
    return this.get("mandatoryValues")?.split("|") || [];
  }

  @computed("item")
  get readOnly() {
    if (typeof this.item === "string") {
      return this.mandatoryValuesArray.includes(this.item);
    }
    return this.mandatoryValuesArray.includes(this.item.id);
  }
}
