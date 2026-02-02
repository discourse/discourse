/* eslint-disable ember/no-classic-components */
import Component, { Input, Textarea } from "@ember/component";
import { tagName } from "@ember-decorators/component";
import TextField from "discourse/components/text-field";

@tagName("")
export default class String extends Component {
  <template>
    <div ...attributes>
      {{#if this.setting.textarea}}
        <Textarea
          @value={{this.value}}
          class="input-setting-textarea"
          @disabled={{@disabled}}
        />
      {{else if this.isSecret}}
        <Input
          @type="password"
          @value={{this.value}}
          class="input-setting-string"
          autocomplete="new-password"
          @disabled={{@disabled}}
        />
      {{else}}
        <TextField
          @value={{this.value}}
          @classNames="input-setting-string"
          @disabled={{@disabled}}
        />
      {{/if}}
    </div>
  </template>
}
