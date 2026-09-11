import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  fieldControl,
  fieldValue,
  findNodeType,
  isExpression,
  normalizePropertyOptions,
  propertyDescription,
  propertyLabel,
} from "../../../lib/workflows/property-engine";
import WorkflowsEmptyState from "../empty-state";
import Field from "./field";

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
    return this.args.formApi?.get(this.args.fieldName) || {};
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

  usesInlineControl(option) {
    return (
      fieldControl(option) === "boolean" &&
      !isExpression(this.currentValue[option.name])
    );
  }

  @action
  collectionRowClass(option) {
    return [
      "workflows-property-engine__collection-row",
      this.usesInlineControl(option) ? "--inline-control" : null,
    ]
      .filter(Boolean)
      .join(" ");
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
    const nextValue = { ...this.currentValue };
    delete nextValue[option.name];
    this.args.formApi.set(this.args.fieldName, nextValue);
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
            <div class={{this.collectionRowClass option}}>

              <DButton
                class="workflows-property-engine__collection-delete"
                @action={{fn this.removeOption option}}
                @icon="xmark"
                @translatedAriaLabel={{i18n
                  "discourse_workflows.property_engine.remove_assignment"
                  name=(this.optionLabel option)
                }}
                @translatedTitle={{i18n
                  "discourse_workflows.property_engine.remove_assignment"
                  name=(this.optionLabel option)
                }}
              />

              <div class="workflows-property-engine__collection-fields">
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
              </div>
            </div>

          {{/each}}
        </@form.Object>

        {{#if this.hasAvailableOptions}}
          <DMenu
            class="btn btn-default workflows-property-engine__add-attrs-btn"
            @inline={{true}}
            @modalForwardRecipient={{true}}
          >
            <:trigger>
              {{this.addOptionLabel}}
              {{dIcon "chevron-down"}}
            </:trigger>
            <:content as |menu|>
              <DDropdownMenu as |dropdown|>
                {{#each this.availableOptions key="name" as |option|}}
                  <dropdown.item>
                    <DButton
                      class="btn-transparent"
                      @action={{fn this.addOption option menu.close}}
                      @translatedLabel={{this.optionLabel option}}
                    />
                  </dropdown.item>
                {{/each}}
              </DDropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      {{/if}}
    </@form.Section>
  </template>
}
