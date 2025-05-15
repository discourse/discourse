import Component from "@ember/component";
import icon from "discourse/helpers/d-icon";

export default class SettingValidationMessage extends Component {
  <template>
    <div
      class="validation-error {{unless this.message 'hidden'}} form-kit__errors"
    >
      {{icon "circle-info"}}
      {{this.message}}
    </div>
  </template>
}
