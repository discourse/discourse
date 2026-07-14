import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  collectionAddLabel,
  emptyCollectionItem,
  emptyFixedCollectionItem,
  fieldType,
  fieldVisible,
  findNodeType,
  fixedCollectionGroup,
  fixedCollectionGroupMultiple,
  fixedCollectionGroups,
  normalizeSchema,
  propertyDescription,
  propertyLabel,
} from "../../../lib/workflows/property-engine";
import WorkflowsEmptyState from "../empty-state";
import Field from "./field";

function isCollection(field) {
  return fieldType(field) === "fixed_collection";
}

function isItemFieldVisible(field, item) {
  return fieldVisible(field, item);
}

function hasNonDefaultValue(item, field) {
  const value = item[field.name];
  if (field.type === "boolean") {
    return value === true;
  }
  return value !== undefined && value !== null && value !== "";
}

function isExtraFieldShown(field, item, activeAttrs, key) {
  if (!fieldVisible(field, item)) {
    return false;
  }
  if (field.display_options?.show) {
    return true;
  }
  const explicit = activeAttrs.get(key);
  if (explicit?.has(field.name)) {
    return true;
  }
  return hasNonDefaultValue(item, field);
}

export default class FixedCollection extends Component {
  @tracked activeAttrs = new Map();
  @tracked itemCounts = new Map();

  get groups() {
    return fixedCollectionGroups(this.args.schema).length
      ? fixedCollectionGroups(this.args.schema)
      : [fixedCollectionGroup(this.args.schema)];
  }

  get hasMultipleGroups() {
    return this.groups.length > 1;
  }

  get addLabel() {
    return (
      this.args.addLabel ||
      collectionAddLabel(
        this.nodeDefinition,
        this.args.fieldName,
        this.args.schema
      )
    );
  }

  get description() {
    return propertyDescription(this.nodeDefinition, this.args.fieldName);
  }

  get label() {
    return (
      this.args.label || propertyLabel(this.nodeDefinition, this.args.fieldName)
    );
  }

  get isFlat() {
    return this.args.schema?.ui?.flat === true;
  }

  get hide_optional_fields() {
    const type_options = this.args.schema.type_options || {};
    return type_options.hide_optional_fields;
  }

  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.args.nodeType)
    );
  }

  get maxItems() {
    const type_options = this.args.schema?.type_options || {};
    return (
      this.args.schema?.max_items ?? type_options.max_allowed_fields ?? null
    );
  }

  get maxItemsReachedTitle() {
    return i18n("discourse_workflows.property_engine.max_items_reached", {
      count: this.maxItems,
    });
  }

  @action
  groupPath(group) {
    return `${this.args.fieldName}.${group.name}`;
  }

  @action
  groupLabel(group) {
    return group.display_name || group.name;
  }

  @action
  isMultiple(group) {
    return fixedCollectionGroupMultiple(group, this.args.schema);
  }

  @action
  itemCount(group) {
    const path = this.groupPath(group);
    if (this.itemCounts.has(path)) {
      return this.itemCounts.get(path);
    }

    const value = this.args.formApi?.get(path);
    if (Array.isArray(value)) {
      return value.length;
    }
    return value && typeof value === "object" ? 1 : 0;
  }

  @action
  atMaxItems(group) {
    return this.maxItems !== null && this.itemCount(group) >= this.maxItems;
  }

  @action
  showEmptyState(group) {
    return this.args.emptyStateDescription && this.itemCount(group) === 0;
  }

  @action
  valuesSchema(group) {
    return group.values || {};
  }

  @action
  allItemFields(group) {
    return normalizeSchema(this.valuesSchema(group));
  }

  @action
  itemFields(group) {
    const fields = this.allItemFields(group);
    if (!this.hide_optional_fields) {
      return fields;
    }

    return fields.filter(
      (field) => field.required || field.show_even_when_optional
    );
  }

  @action
  extraItemFields(group) {
    const explicitExtra = normalizeSchema(
      this.args.schema.extra_item_schema || {}
    );
    if (!this.hide_optional_fields) {
      return explicitExtra;
    }

    return [
      ...explicitExtra,
      ...this.allItemFields(group).filter(
        (field) => !field.required && !field.show_even_when_optional
      ),
    ];
  }

  @action
  hasExtraFieldsFor(group) {
    return this.extraItemFields(group).length > 0;
  }

  @action
  emptyItem(group) {
    return emptyFixedCollectionItem(group);
  }

  @action
  addItem(group) {
    if (this.atMaxItems(group)) {
      return;
    }
    const path = this.groupPath(group);
    const item = this.args.emptyItem
      ? this.args.emptyItem()
      : this.emptyItem(group);
    this.args.form.addItemToCollection(path, item);
    this.args.onAdd?.(item);
    this.itemCounts = new Map(this.itemCounts).set(
      path,
      this.itemCount(group) + 1
    );
    this.args.onChange?.();
  }

  @action
  fieldLabel(fieldName) {
    return propertyLabel(this.nodeDefinition, fieldName);
  }

  @action
  removeItem(group, removeFn, index) {
    this.args.onRemove?.(index);
    const path = this.groupPath(group);
    const newMap = new Map(this.activeAttrs);
    newMap.delete(`${group.name}:${index}`);
    this.activeAttrs = newMap;
    removeFn(index);
    this.itemCounts = new Map(this.itemCounts).set(
      path,
      Math.max(this.itemCount(group) - 1, 0)
    );
    this.args.onChange?.();
  }

  @action
  isAttrActive(group, index, field, item) {
    return isExtraFieldShown(
      field,
      item,
      this.activeAttrs,
      this.activeAttrKey(group, index)
    );
  }

  @action
  activeAttrKey(group, index) {
    return `${group.name}:${index}`;
  }

  @action
  toggleAttr(group, index, field, item, close) {
    const key = `${group.name}:${index}`;
    const active = this.isAttrActive(group, index, field, item);
    const newMap = new Map(this.activeAttrs);
    const set = new Set(newMap.get(key) || []);

    if (active) {
      set.delete(field.name);
      const defaultVal =
        field.type === "boolean" ? false : (field.default ?? "");
      this.args.formApi.set(
        `${this.groupPath(group)}.${index}.${field.name}`,
        defaultVal
      );
    } else {
      set.add(field.name);
    }

    newMap.set(key, set);
    this.activeAttrs = newMap;
    close?.();
  }

  @action
  nestedItemFields(extraField) {
    return normalizeSchema(fixedCollectionGroup(extraField).values || {});
  }

  @action
  nestedCollectionName(extraField) {
    return `${extraField.name}.${fixedCollectionGroup(extraField).name}`;
  }

  @action
  addNestedItem(group, parentIndex, extraField) {
    const nestedGroup = fixedCollectionGroup(extraField);
    const path = `${this.groupPath(group)}.${parentIndex}.${extraField.name}.${nestedGroup.name}`;
    const current = this.args.formApi.get(path) || [];
    const newItem = emptyCollectionItem(nestedGroup.values || {});
    this.args.formApi.set(path, [...current, newItem]);
  }

  @action
  removeNestedItem(removeFn, index) {
    removeFn(index);
    this.args.onChange?.();
  }

  @action
  availableExtraFields(group, item) {
    return this.extraItemFields(group).filter((field) =>
      fieldVisible(field, item)
    );
  }

  <template>
    <@form.Section @title={{this.label}} @subtitle={{this.description}}>
      {{#each this.groups key="name" as |group|}}
        {{#if this.hasMultipleGroups}}
          <span class="workflows-property-engine__block-field-label">
            {{this.groupLabel group}}
          </span>
        {{/if}}

        {{#if (this.isMultiple group)}}
          <@form.Collection
            @name={{this.groupPath group}}
            @tagName="div"
            as |collection index item|
          >
            <div class="workflows-property-engine__collection-row">

              <DButton
                @action={{fn this.removeItem group collection.remove index}}
                @icon="xmark"
                class="workflows-property-engine__collection-delete"
                @translatedAriaLabel={{i18n
                  "discourse_workflows.property_engine.remove_assignment"
                  name=item.name
                }}
                @translatedTitle={{i18n
                  "discourse_workflows.property_engine.remove_assignment"
                  name=item.name
                }}
              />

              <collection.Object
                class={{if
                  this.isFlat
                  "workflows-property-engine__collection-flat"
                  "workflows-property-engine__collection-fields"
                }}
                as |object|
              >
                {{#if (has-block)}}
                  {{yield (hash object=object item=item index=index)}}
                {{else}}
                  {{#each (this.itemFields group) key="name" as |itemField|}}
                    {{#if (isItemFieldVisible itemField item)}}
                      <Field
                        @form={{object}}
                        @formApi={{@formApi}}
                        @configuration={{item}}
                        @connections={{@connections}}
                        @credentials={{@credentials}}
                        @fieldName={{itemField.name}}
                        @node={{@node}}
                        @nodeDefinition={{this.nodeDefinition}}
                        @nodeParameters={{@nodeParameters}}
                        @nodeType={{@nodeType}}
                        @nodes={{@nodes}}
                        @nodeTypes={{@nodeTypes}}
                        @schema={{itemField}}
                        @session={{@session}}
                      />
                    {{/if}}
                  {{/each}}

                  {{#each
                    (this.extraItemFields group) key="name"
                    as |extraField|
                  }}
                    {{#if
                      (isExtraFieldShown
                        extraField
                        item
                        this.activeAttrs
                        (this.activeAttrKey group index)
                      )
                    }}
                      {{#if (isCollection extraField)}}
                        <div
                          class="workflows-property-engine__nested-collection"
                        >
                          <span
                            class="workflows-property-engine__block-field-label"
                          >{{this.fieldLabel extraField.name}}</span>

                          <object.Collection
                            @name={{this.nestedCollectionName extraField}}
                            @tagName="div"
                            as |subCollection subIndex|
                          >
                            <subCollection.Object
                              class="workflows-property-engine__nested-collection-item"
                              as |subObject|
                            >

                              {{#each
                                (this.nestedItemFields extraField) key="name"
                                as |subField|
                              }}
                                <Field
                                  @form={{subObject}}
                                  @formApi={{@formApi}}
                                  @connections={{@connections}}
                                  @credentials={{@credentials}}
                                  @fieldName={{subField.name}}
                                  @node={{@node}}
                                  @nodeDefinition={{this.nodeDefinition}}
                                  @nodeParameters={{@nodeParameters}}
                                  @nodeType={{@nodeType}}
                                  @nodes={{@nodes}}
                                  @nodeTypes={{@nodeTypes}}
                                  @schema={{subField}}
                                  @session={{@session}}
                                />
                              {{/each}}

                              <DButton
                                @action={{fn
                                  this.removeNestedItem
                                  subCollection.remove
                                  subIndex
                                }}
                                @icon="xmark"
                                class="workflows-property-engine__collection-delete"
                              />
                            </subCollection.Object>
                          </object.Collection>

                          <DButton
                            @action={{fn
                              this.addNestedItem
                              group
                              index
                              extraField
                            }}
                            @icon="plus"
                            @translatedLabel={{i18n
                              "discourse_workflows.property_engine.add_item"
                            }}
                            class="btn-default btn-small"
                          />
                        </div>
                      {{else}}
                        <Field
                          @form={{object}}
                          @formApi={{@formApi}}
                          @connections={{@connections}}
                          @credentials={{@credentials}}
                          @fieldName={{extraField.name}}
                          @node={{@node}}
                          @nodeDefinition={{this.nodeDefinition}}
                          @nodeParameters={{@nodeParameters}}
                          @nodeType={{@nodeType}}
                          @nodes={{@nodes}}
                          @nodeTypes={{@nodeTypes}}
                          @schema={{extraField}}
                          @session={{@session}}
                        />
                      {{/if}}
                    {{/if}}
                  {{/each}}

                  {{#if (this.hasExtraFieldsFor group)}}
                    <div class="workflows-property-engine__block-actions">
                      <DMenu
                        class="btn btn-default workflows-property-engine__add-attrs-btn"
                        @inline={{true}}
                        @modalForwardRecipient={{true}}
                      >
                        <:trigger>
                          {{i18n
                            "discourse_workflows.property_engine.add_attributes"
                          }}
                          {{dIcon "chevron-down"}}
                        </:trigger>
                        <:content as |menu|>
                          <DDropdownMenu as |dropdown|>
                            {{#each
                              (this.availableExtraFields group item) key="name"
                              as |extraField|
                            }}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent"
                                  @action={{fn
                                    this.toggleAttr
                                    group
                                    index
                                    extraField
                                    item
                                    menu.close
                                  }}
                                  @translatedLabel={{this.fieldLabel
                                    extraField.name
                                  }}
                                  @icon={{if
                                    (this.isAttrActive
                                      group index extraField item
                                    )
                                    "check"
                                  }}
                                />
                              </dropdown.item>
                            {{/each}}
                          </DDropdownMenu>
                        </:content>
                      </DMenu>
                    </div>
                  {{/if}}
                {{/if}}
              </collection.Object>
            </div>
          </@form.Collection>

          {{#if (this.showEmptyState group)}}
            <WorkflowsEmptyState
              @description={{@emptyStateDescription}}
              @onAction={{fn this.addItem group}}
              @buttonIcon="plus"
              @translatedButtonLabel={{this.addLabel}}
            />
          {{else}}
            <DButton
              @action={{fn this.addItem group}}
              @icon="plus"
              @translatedLabel={{this.addLabel}}
              @disabled={{this.atMaxItems group}}
              @translatedTitle={{this.maxItemsReachedTitle}}
              class="btn-default"
            />
          {{/if}}
        {{else}}
          <@form.Object
            @name={{this.groupPath group}}
            class={{if
              this.isFlat
              "workflows-property-engine__collection-flat"
              "workflows-property-engine__collection-fields"
            }}
            as |object item|
          >
            {{#each (this.allItemFields group) key="name" as |itemField|}}
              {{#if (isItemFieldVisible itemField item)}}
                <Field
                  @form={{object}}
                  @formApi={{@formApi}}
                  @configuration={{item}}
                  @connections={{@connections}}
                  @credentials={{@credentials}}
                  @fieldName={{itemField.name}}
                  @node={{@node}}
                  @nodeDefinition={{this.nodeDefinition}}
                  @nodeParameters={{@nodeParameters}}
                  @nodeType={{@nodeType}}
                  @nodes={{@nodes}}
                  @nodeTypes={{@nodeTypes}}
                  @schema={{itemField}}
                  @session={{@session}}
                />
              {{/if}}
            {{/each}}
          </@form.Object>
        {{/if}}
      {{/each}}
    </@form.Section>
  </template>
}
