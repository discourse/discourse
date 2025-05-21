import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import Form from "discourse/components/form";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import SiteSetting from "admin/models/site-setting";

const PrimaryActions = <template>
  <@actions as |actions|>
    <actions.Button @icon="gear" />
  </@actions>
</template>;

export default class FormKitSiteSettingWrapper extends Component {
  get settingTitle() {
    return humanizedSettingName(
      this.args.setting.setting,
      this.args.setting.label
    );
  }

  @cached
  get formData() {
    return {
      [this.args.setting.setting]: this.args.setting.value,
    };
  }

  @action
  async save(data) {
    this.args.setting.buffered.set(
      this.args.setting.setting,
      data[this.args.setting.setting]
    );
    this.args.setting.buffered.applyChanges();

    const params = {};
    params[this.args.setting.setting] = {
      value: data[this.args.setting.setting],
      backfill: false,
    };

    await SiteSetting.bulkUpdate(params);
  }

  <template>
    <Form
      @submitOn="focusout"
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class={{if @setting.overridden "--overridden"}}
      as |form|
    >
      <form.Field
        @name={{@setting.setting}}
        @title={{this.settingTitle}}
        @description={{htmlSafe @setting.description}}
        @primaryActionsComponent={{component PrimaryActions setting=@setting}}
      >
        <:primary-actions>
          primary-actions
        </:primary-actions>
        <:body as |field|>
          {{#if (eq @setting.type "string")}}
            <field.Input />
          {{else if (eq @setting.type "upload")}}
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
        </:body>
      </form.Field>
    </Form>
  </template>
}
