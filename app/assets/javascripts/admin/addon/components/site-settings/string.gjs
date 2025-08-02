import Component, { Input, Textarea } from "@ember/component";
import TextField from "discourse/components/text-field";

export default class String extends Component {
  <template>
    {{#if this.setting.textarea}}
      <Textarea @value={{this.value}} class="input-setting-textarea" />
    {{else if this.isSecret}}
      <Input
        @type="password"
        @value={{this.value}}
        class="input-setting-string"
        autocomplete="new-password"
      />
    {{else}}
      <TextField @value={{this.value}} @classNames="input-setting-string" />
    {{/if}}
  </template>
}
