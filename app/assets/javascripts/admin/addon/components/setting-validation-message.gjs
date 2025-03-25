import Component from "@ember/component";
import dIcon from "discourse/helpers/d-icon";

export default class SettingValidationMessage extends Component {
  <template>
    <div class="validation-error {{unless this.message 'hidden'}}">
      {{dIcon "xmark"}}
      {{this.message}}
    </div>
  </template>
}
