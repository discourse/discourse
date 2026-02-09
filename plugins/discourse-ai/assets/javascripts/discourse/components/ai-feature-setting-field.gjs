import Component from "@glimmer/component";
import { service } from "@ember/service";
import ListSetting from "discourse/select-kit/components/list-setting";
import { eq } from "discourse/truth-helpers";

export default class AiFeatureSettingField extends Component {
  @service site;

  parseList = (value) => {
    return value?.toString().split("|").filter(Boolean) || [];
  };

  serializeList = (callback) => {
    return (values) => {
      callback(Array.isArray(values) ? values.join("|") : values);
    };
  };

  get groupChoices() {
    return (this.site.groups || []).map((g) => ({
      name: g.name,
      id: g.id.toString(),
    }));
  }

  get hasEnumChoices() {
    return this.args.setting.valid_values?.length > 0;
  }

  get compactListChoices() {
    if (this.hasEnumChoices) {
      return this.args.setting.valid_values.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }
    return this.args.setting.choices;
  }

  get controlType() {
    const { type, list_type } = this.args.setting;

    if (type === "list" && list_type) {
      return `${list_type}_list`;
    }
    return type;
  }

  <template>
    {{#if (eq this.controlType "bool")}}
      <@field.Checkbox>
        {{@setting.description}}
      </@field.Checkbox>
    {{else if (eq this.controlType "integer")}}
      <@field.Input @type="number" />
    {{else if (eq this.controlType "enum")}}
      <@field.Select as |select|>
        {{#each @setting.valid_values as |option|}}
          <select.Option @value={{option.value}}>
            {{option.name}}
          </select.Option>
        {{/each}}
      </@field.Select>
    {{else if (eq this.controlType "group_list")}}
      <@field.Custom>
        <ListSetting
          @value={{this.parseList @field.value}}
          @choices={{this.groupChoices}}
          @settingName={{@setting.setting}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.serializeList @field.set}}
        />
      </@field.Custom>
    {{else if (eq this.controlType "compact_list")}}
      <@field.Custom>
        <ListSetting
          @value={{this.parseList @field.value}}
          @choices={{this.compactListChoices}}
          @settingName={{@setting.setting}}
          @nameProperty={{if this.hasEnumChoices "name"}}
          @valueProperty={{if this.hasEnumChoices "value"}}
          @onChange={{this.serializeList @field.set}}
        />
      </@field.Custom>
    {{else}}
      <@field.Input />
    {{/if}}
  </template>
}
