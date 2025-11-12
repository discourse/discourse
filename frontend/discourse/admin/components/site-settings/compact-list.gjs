import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class CompactList extends Component {
  @tracked createdChoices = null;
  tokenSeparator = "|";

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  get settingChoices() {
    return uniqueItemsFromArray([
      ...makeArray(this.settingValue),
      ...makeArray(this.args.setting.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = uniqueItemsFromArray([
      ...makeArray(this.createdChoices),
      ...makeArray(choices),
    ]);
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{@setting.setting}}
      @choices={{this.settingChoices}}
      @onChange={{this.onChangeListSetting}}
      @onChangeChoices={{this.onChangeChoices}}
      @options={{hash allowAny=@allowAny}}
      @mandatoryValues={{@setting.mandatory_values}}
    />
  </template>
}
