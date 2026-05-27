/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@tagName("")
export default class SettingValidationMessage extends Component {
  <template>
    <div ...attributes>
      <div class="validation-error {{unless this.message 'hidden'}}">
        {{dIcon "xmark"}}
        {{this.message}}
      </div>
    </div>
  </template>
}
