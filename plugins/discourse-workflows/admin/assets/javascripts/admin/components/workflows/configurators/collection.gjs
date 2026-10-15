import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  keyedValue,
  withoutKey,
} from "../../../lib/workflows/keyed-collection.js";
import {
  fieldValue,
  findNodeType,
  normalizePropertyOptions,
  propertyDescription,
  propertyLabel,
  usesInlineBooleanControl,
} from "../../../lib/workflows/property-engine.js";
import WorkflowsEmptyState from "../empty-state.gjs";
import CollectionAddMenu from "./collection-add-menu.gjs";
import CollectionOptionRow from "./collection-option-row.gjs";
import Field from "./field.gjs";

export default class Collection extends Component {
  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.args.nodeType)
    );
  }

  get label() {
    return (
      this.args.label || propertyLabel(this.nodeDefinition, this.args.fieldName)
    );
  }

  get description() {
    return propertyDescription(this.nodeDefinition, this.args.fieldName);
  }

  get addLabel() {
    return (
      this.args.addLabel || i18n("discourse_workflows.property_engine.add_item")
    );
  }

  get addOptionLabel() {
    const labelKey =
      this.args.schema?.type_options?.add_optional_field_button_text;

    return labelKey
      ? i18n(labelKey)
      : i18n("discourse_workflows.property_engine.add_option");
  }

  get isArrayCollection() {
    return Boolean(this.args.emptyItem);
  }

  get arrayItems() {
    return this.args.formApi?.get(this.args.fieldName) || [];
  }

  get showEmptyState() {
    return this.args.emptyStateDescription && this.arrayItems.length === 0;
  }

  get currentValue() {
    return keyedValue(this.args.formApi?.get(this.args.fieldName));
  }

  get options() {
    return normalizePropertyOptions(this.args.schema.options || []);
  }

  get selectedOptions() {
    return this.options.filter((option) =>
      Object.hasOwn(this.currentValue, option.name)
    );
  }

  get availableOptions() {
    return this.options.filter(
      (option) => !Object.hasOwn(this.currentValue, option.name)
    );
  }

  get hasAvailableOptions() {
    return this.availableOptions.length > 0;
  }

  @action
  usesInlineControl(option) {
    return usesInlineBooleanControl(option, this.currentValue[option.name]);
  }

  @action
  optionLabel(option) {
    return (
      propertyLabel(this.nodeDefinition, option.name) ||
      option.display_name ||
      option.name
    );
  }

  @action
  addOption(option, close) {
    this.args.formApi.set(this.args.fieldName, {
      ...this.currentValue,
      [option.name]: fieldValue(option),
    });
    close?.();
  }

  @action
  removeOption(option) {
    this.args.formApi.set(
      this.args.fieldName,
      withoutKey(this.currentValue, option.name)
    );
  }

  @action
  addItem() {
    const item = this.args.emptyItem();
    this.args.form.addItemToCollection(this.args.fieldName, item);
    this.args.onAdd?.(item);
    this.args.onChange?.();
  }

  @action
  removeItem(removeFn, index) {
    this.args.onRemove?.(index);
    removeFn(index);
    this.args.onChange?.();
  }

  <template>
    <@form.Section @subtitle={{this.description}} @title={{this.label}}>
      {{#if this.isArrayCollection}}
        <@form.Collection
          @name={{@fieldName}}
          @tagName="div"
          as |collection index item|
        >
          <div class="workflows-property-engine__collection-row">
            <div class="workflows-property-engine__collection-delete">
              <DButton
                class="btn-transparent btn-small btn-danger"
                @action={{fn this.removeItem collection.remove index}}
                @icon="trash-can"
              />
            </div>

            <collection.Object
              class="workflows-property-engine__collection-fields"
              as |object|
            >
              {{yield (hash object=object item=item index=index)}}
            </collection.Object>
          </div>
        </@form.Collection>

        {{#if this.showEmptyState}}
          <WorkflowsEmptyState
            @buttonIcon="plus"
            @description={{@emptyStateDescription}}
            @onAction={{this.addItem}}
            @translatedButtonLabel={{this.addLabel}}
          />
        {{else}}
          <DButton
            class="btn-default"
            @action={{this.addItem}}
            @icon="plus"
            @translatedLabel={{this.addLabel}}
          />
        {{/if}}
      {{else}}
        <@form.Object @name={{@fieldName}} as |object item|>
          {{#each this.selectedOptions key="name" as |option|}}
            <CollectionOptionRow
              @inlineControl={{this.usesInlineControl option}}
              @onRemove={{fn this.removeOption option}}
              @removeLabel={{i18n
                "discourse_workflows.property_engine.remove_assignment"
                name=(this.optionLabel option)
              }}
            >
              <Field
                @configuration={{item}}
                @connections={{@connections}}
                @credentials={{@credentials}}
                @fieldName={{option.name}}
                @form={{object}}
                @formApi={{@formApi}}
                @label={{this.optionLabel option}}
                @node={{@node}}
                @nodeDefinition={{this.nodeDefinition}}
                @nodeParameters={{@nodeParameters}}
                @nodes={{@nodes}}
                @nodeType={{@nodeType}}
                @nodeTypes={{@nodeTypes}}
                @schema={{option}}
                @session={{@session}}
                @showOptional={{false}}
              />
            </CollectionOptionRow>
          {{/each}}
        </@form.Object>

        {{#if this.hasAvailableOptions}}
          <CollectionAddMenu
            @label={{this.addOptionLabel}}
            @onAdd={{this.addOption}}
            @optionLabel={{this.optionLabel}}
            @options={{this.availableOptions}}
          />
        {{/if}}
      {{/if}}
    </@form.Section>
  </template>
}
