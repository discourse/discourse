import { action, computed } from "@ember/object";
import Component from "@ember/component";

export default class GroupList extends Component {
  tokenSeparator = "|";
  nameProperty = "name";
  valueProperty = "id";

  @computed("site.groups")
  get groupChoices() {
    return (this.site.groups || []).map((g) => {
      return { name: g.name, id: g.id.toString() };
    });
  }

  @computed("value")
  get settingValue() {
    return (this.value || "").split(this.tokenSeparator).filter(Boolean);
  }

  @action
  onChangeGroupListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  }
}
