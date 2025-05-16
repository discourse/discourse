import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import Form from "discourse/components/form";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";

export default class FormKitSiteSettingWrapper extends Component {
  get settingTitle() {
    return humanizedSettingName(
      this.args.setting.setting,
      this.args.setting.label
    );
  }

  <template>
    <Form class={{if @setting.overridden "--overridden"}} as |form|>
      <form.Field
        @name={{@setting.setting}}
        @title={{this.settingTitle}}
        @description={{htmlSafe @setting.description}}
        as |field|
      >
        {{#if (eq @setting.type "string")}}
          <field.Input />
        {{else if (eq @setting.type "upload")}}
          {{log @setting}}
          <field.Image @type="site_setting" />
        {{else if (eq @setting.type "bool")}}
          <field.Checkbox>
            {{htmlSafe @setting.description}}
          </field.Checkbox>
        {{else if (eq @setting.type "enum")}}
          <field.Select as |select|>
            {{#each @setting.valid_values as |item|}}
              <select.Option @value={{item.value}}>
                {{item.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        {{/if}}
      </form.Field>
    </Form>
  </template>
}
