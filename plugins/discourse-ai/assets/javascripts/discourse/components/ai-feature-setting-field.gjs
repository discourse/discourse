import Component from "@glimmer/component";
import { service } from "@ember/service";
import ValueList from "discourse/admin/components/value-list";
import ListSetting from "discourse/select-kit/components/list-setting";
import { eq } from "discourse/truth-helpers";

export default class AiFeatureSettingField extends Component {
  @service site;

  parseGroupList = (value) => {
    if (!value) {
      return [];
    }
    return value.toString().split("|").filter(Boolean);
  };

  serializeListValue = (callback) => {
    return (values) => {
      const serialized = Array.isArray(values) ? values.join("|") : values;
      callback(serialized);
    };
  };

  get groupChoices() {
    return (this.site.groups || []).map((g) => {
      return { name: g.name, id: g.id.toString() };
    });
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
          @value={{this.parseGroupList @field.value}}
          @choices={{this.groupChoices}}
          @settingName={{@setting.setting}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.serializeListValue @field.set}}
        />
      </@field.Custom>
    {{else if (eq this.controlType "compact_list")}}
      <@field.Custom>
        <ValueList
          @values={{@field.value}}
          @choices={{@setting.choices}}
          @inputDelimiter="|"
          @onChange={{this.serializeListValue @field.set}}
        />
      </@field.Custom>
    {{else}}
      <@field.Input />
    {{/if}}
  </template>
}
