/* eslint-disable ember/no-classic-components */
import Component, { Input, Textarea } from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DTextField from "discourse/ui-kit/d-text-field";

@tagName("")
export default class String extends Component {
  <template>
    <div ...attributes>
      {{#if this.setting.textarea}}
        <Textarea
          class="input-setting-textarea"
          @disabled={{@disabled}}
          @value={{this.value}}
        />
      {{else if this.isSecret}}
        <Input
          autocomplete="new-password"
          class="input-setting-string"
          @disabled={{@disabled}}
          @type="password"
          @value={{this.value}}
        />
      {{else}}
        <DTextField
          @classNames="input-setting-string"
          @disabled={{@disabled}}
          @value={{this.value}}
        />
      {{/if}}
    </div>
  </template>
}
