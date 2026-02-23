/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";

@tagName("")
export default class SettingValidationMessage extends Component {
  <template>
    <div ...attributes>
      <div class="validation-error {{unless this.message 'hidden'}}">
        {{icon "xmark"}}
        {{this.message}}
      </div>
    </div>
  </template>
}
