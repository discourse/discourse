/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { tagName } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";

@tagName("")
export default class Enum extends Component {
  <template>
    <div ...attributes>
      <ComboBox
        @content={{this.setting.validValues}}
        @nameProperty={{this.setting.computedNameProperty}}
        @onChange={{fn (mut this.value)}}
        @options={{hash
          castInteger=true
          allowAny=this.setting.allowsNone
          disabled=@disabled
        }}
        @value={{this.value}}
        @valueProperty={{this.setting.computedValueProperty}}
      />

      {{this.preview}}
    </div>
  </template>
}
