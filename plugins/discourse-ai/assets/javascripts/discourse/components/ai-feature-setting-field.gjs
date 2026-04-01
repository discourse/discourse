import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import ListSetting from "discourse/select-kit/components/list-setting";
import { eq } from "discourse/truth-helpers";

export default class AiFeatureSettingField extends Component {
  @service site;

  @tracked selectedCategories = [];

  parseList = (value) => {
    return value?.toString().split("|").filter(Boolean) || [];
  };

  serializeList = (callback) => {
    return (values) => {
      callback(Array.isArray(values) ? values.join("|") : values);
    };
  };

  constructor() {
    super(...arguments);
    if (this.controlType === "category_list") {
      this.#loadCategories();
    }
  }

  get groupChoices() {
    return (this.site.groups || []).map((g) => ({
      name: g.name,
      id: g.id.toString(),
    }));
  }

  async #loadCategories() {
    const ids = this.#categoryIds;
    if (ids.length) {
      this.selectedCategories = await Category.asyncFindByIds(ids);
    }
  }

  get #categoryIds() {
    return (this.args.field?.value || "").toString().split("|").filter(Boolean);
  }

  @action
  categoryValueChanged() {
    this.#loadCategories();
  }

  @action
  onChangeCategories(categories) {
    const value = (categories || []).map((c) => c.id).join("|");
    this.args.field.set(value);
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
      <@Control>
        {{@setting.description}}
      </@Control>
    {{else if (eq this.controlType "integer")}}
      <@Control />
    {{else if (eq this.controlType "enum")}}
      <@Control as |select|>
        {{#each @setting.valid_values as |option|}}
          <select.Option @value={{option.value}}>
            {{option.name}}
          </select.Option>
        {{/each}}
      </@Control>
    {{else if (eq this.controlType "category_list")}}
      <@Control>
        <div {{didUpdate this.categoryValueChanged @field.value}}>
          <CategorySelector
            @categories={{this.selectedCategories}}
            @onChange={{this.onChangeCategories}}
          />
        </div>
      </@Control>
    {{else if (eq this.controlType "group_list")}}
      <@Control>
        <ListSetting
          @value={{this.parseList @field.value}}
          @choices={{this.groupChoices}}
          @settingName={{@setting.setting}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.serializeList @field.set}}
        />
      </@Control>
    {{else if (eq this.controlType "compact_list")}}
      <@Control>
        <ListSetting
          @value={{this.parseList @field.value}}
          @choices={{this.compactListChoices}}
          @settingName={{@setting.setting}}
          @nameProperty={{if this.hasEnumChoices "name"}}
          @valueProperty={{if this.hasEnumChoices "value"}}
          @onChange={{this.serializeList @field.set}}
        />
      </@Control>
    {{else}}
      <@Control />
    {{/if}}
  </template>
}
