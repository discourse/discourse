/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";

@tagName("")
export default class Group extends Component {
  @computed("site.groups", "setting.disallowed_groups")
  get groupChoices() {
    const disallowed = (this.setting?.disallowed_groups || "")
      .split("|")
      .filter(Boolean);

    return (this.site.groups || [])
      .filter((g) => !disallowed.includes(g.id.toString()))
      .map((g) => ({ name: g.name, id: g.id.toString() }));
  }

  @action
  onChange(value) {
    this.changeValueCallback?.(value ?? "");
  }

  <template>
    <div ...attributes>
      <ComboBox
        @value={{@value}}
        @content={{this.groupChoices}}
        @onChange={{this.onChange}}
        @options={{hash clearable=true}}
      />
    </div>
  </template>
}
