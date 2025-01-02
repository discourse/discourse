import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";
import ListSetting from "select-kit/components/list-setting";

export default class CompactList extends Component {
  @tracked createdChoices = null;
  tokenSeparator = "|";

  @computed("args.value")
  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  @computed("settingValue", "setting.choices.[]", "createdChoices.[]")
  get settingChoices() {
    return [
      ...new Set([
        ...makeArray(this.settingValue),
        ...makeArray(this.args.setting.choices),
        ...makeArray(this.createdChoices),
      ]),
    ];
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = [
      ...new Set([...makeArray(this.createdChoices), ...makeArray(choices)]),
    ];
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
