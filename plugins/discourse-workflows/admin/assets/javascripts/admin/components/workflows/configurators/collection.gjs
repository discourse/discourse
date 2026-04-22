import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  collectionAddLabel,
  emptyCollectionItem,
  fieldVisible,
  findNodeType,
  normalizeSchema,
  propertyDescription,
  propertyLabel,
} from "../../../lib/workflows/property-engine";
import WorkflowsEmptyState from "../empty-state";
import Field from "./field";

function isCollection(field) {
  return field.type === "collection";
}

function isItemFieldVisible(field, item) {
  return fieldVisible(field, item);
}

function isExtraFieldShown(field, item, activeAttrs, index) {
  if (!fieldVisible(field, item)) {
    return false;
  }
  if (field.visible_if) {
    return true;
  }
  const explicit = activeAttrs.get(index);
  if (explicit?.has(field.name)) {
    return true;
  }
  return hasNonDefaultValue(item, field);
}

function hasNonDefaultValue(item, field) {
  const value = item[field.name];
  if (field.type === "boolean") {
    return value === true;
  }
  return value !== undefined && value !== null && value !== "";
}

export default class Collection extends Component {
  @tracked activeAttrs = new Map();
  @tracked
  itemCount = (this.args.formApi?.get(this.args.fieldName) || []).length;

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

  get itemFields() {
    return normalizeSchema(this.args.schema.item_schema || {});
  }

  get extraItemFields() {
    return normalizeSchema(this.args.schema.extra_item_schema || {});
  }

  get hasExtraFields() {
    return this.extraItemFields.length > 0;
  }

  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.args.nodeType)
    );
  }

  get metadata() {
    return this.args.metadata || this.nodeDefinition?.metadata || {};
  }

  get emptyItem() {
    return emptyCollectionItem(
      this.args.schema.item_schema || {},
      this.args.schema.extra_item_schema || {}
    );
  }

  get showEmptyState() {
    return this.args.emptyStateDescription && this.itemCount === 0;
  }

  @action
  addItem() {
    const item = this.args.emptyItem ? this.args.emptyItem() : this.emptyItem;
    this.args.form.addItemToCollection(this.args.fieldName, item);
    this.args.onAdd?.(item);
    this.itemCount++;
  }

  @action
  fieldLabel(fieldName) {
    return propertyLabel(this.nodeDefinition, fieldName);
  }

  @action
  removeItem(removeFn, index) {
    this.args.onRemove?.(index);
    const newMap = new Map(this.activeAttrs);
    newMap.delete(index);
    this.activeAttrs = newMap;
    removeFn(index);
    this.itemCount--;
  }

  @action
  isAttrActive(index, field, item) {
    return isExtraFieldShown(field, item, this.activeAttrs, index);
  }

  @action
  toggleAttr(index, field, item) {
    const active = this.isAttrActive(index, field, item);
    const newMap = new Map(this.activeAttrs);
    const set = new Set(newMap.get(index) || []);

    if (active) {
      set.delete(field.name);
      const defaultVal =
        field.type === "boolean" ? false : (field.default ?? "");
      this.args.formApi.set(
        `${this.args.fieldName}.${index}.${field.name}`,
        defaultVal
      );
    } else {
      set.add(field.name);
    }

    newMap.set(index, set);
    this.activeAttrs = newMap;
  }

  @action
  nestedItemFields(extraField) {
    return normalizeSchema(extraField.item_schema || {});
  }

  @action
  addNestedItem(parentIndex, extraField) {
    const path = `${this.args.fieldName}.${parentIndex}.${extraField.name}`;
    const current = this.args.formApi.get(path) || [];
    const newItem = emptyCollectionItem(extraField.item_schema || {});
    this.args.formApi.set(path, [...current, newItem]);
  }

  @action
  availableExtraFields(item) {
    return this.extraItemFields.filter((field) => fieldVisible(field, item));
  }

  <template>
    <@form.Section
      @title={{if this.itemCount this.label}}
      @subtitle={{if this.itemCount this.description}}
    >
      <@form.Collection
        @name={{@fieldName}}
        @tagName="div"
        as |collection index item|
      >
        <div class="workflows-property-engine__collection-row">
          <div class="workflows-property-engine__collection-delete">
            <DButton
              @action={{fn this.removeItem collection.remove index}}
              @icon="trash-can"
              class="btn-transparent btn-small btn-danger"
            />
          </div>

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
              {{#each this.itemFields key="name" as |itemField|}}
                {{#if (isItemFieldVisible itemField item)}}
                  <Field
                    @form={{object}}
                    @formApi={{@formApi}}
                    @configuration={{item}}
                    @fieldName={{itemField.name}}
                    @nodeDefinition={{this.nodeDefinition}}
                    @nodeType={{@nodeType}}
                    @nodeTypes={{@nodeTypes}}
                    @schema={{itemField}}
                  />
                {{/if}}
              {{/each}}

              {{#each this.extraItemFields key="name" as |extraField|}}
                {{#if
                  (isExtraFieldShown extraField item this.activeAttrs index)
                }}
                  {{#if (isCollection extraField)}}
                    <div class="workflows-property-engine__nested-collection">
                      <span
                        class="workflows-property-engine__block-field-label"
                      >{{this.fieldLabel extraField.name}}</span>

                      <object.Collection
                        @name={{extraField.name}}
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
                              @fieldName={{subField.name}}
                              @nodeDefinition={{this.nodeDefinition}}
                              @nodeType={{@nodeType}}
                              @nodeTypes={{@nodeTypes}}
                              @schema={{subField}}
                            />
                          {{/each}}

                          <DButton
                            @action={{fn subCollection.remove subIndex}}
                            @icon="trash-can"
                            class="btn-flat btn-danger btn-small"
                          />
                        </subCollection.Object>
                      </object.Collection>

                      <DButton
                        @action={{fn this.addNestedItem index extraField}}
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
                      @fieldName={{extraField.name}}
                      @nodeDefinition={{this.nodeDefinition}}
                      @nodeType={{@nodeType}}
                      @nodeTypes={{@nodeTypes}}
                      @schema={{extraField}}
                    />
                  {{/if}}
                {{/if}}
              {{/each}}

              {{#if this.hasExtraFields}}
                <div class="workflows-property-engine__block-actions">
                  <DMenu
                    class="btn-flat workflows-property-engine__add-attrs-btn"
                    @inline={{true}}
                    @modalForwardRecipient={{true}}
                  >
                    <:trigger>
                      {{i18n
                        "discourse_workflows.property_engine.add_attributes"
                      }}
                      {{icon "chevron-down"}}
                    </:trigger>
                    <:content>
                      <DropdownMenu as |dropdown|>
                        {{#each
                          (this.availableExtraFields item) key="name"
                          as |extraField|
                        }}
                          <dropdown.item>
                            <DButton
                              class="btn-transparent"
                              @action={{fn
                                this.toggleAttr
                                index
                                extraField
                                item
                              }}
                              @translatedLabel={{this.fieldLabel
                                extraField.name
                              }}
                              @icon={{if
                                (this.isAttrActive index extraField item)
                                "check"
                              }}
                            />
                          </dropdown.item>
                        {{/each}}
                      </DropdownMenu>
                    </:content>
                  </DMenu>
                </div>
              {{/if}}
            {{/if}}
          </collection.Object>
        </div>
      </@form.Collection>

      {{#if this.showEmptyState}}
        <WorkflowsEmptyState
          @description={{@emptyStateDescription}}
          @onAction={{this.addItem}}
          @buttonIcon="plus"
          @translatedButtonLabel={{this.addLabel}}
        />
      {{else}}
        <DButton
          @action={{this.addItem}}
          @icon="plus"
          @translatedLabel={{this.addLabel}}
          class="btn-default"
        />
      {{/if}}
    </@form.Section>
  </template>
}
