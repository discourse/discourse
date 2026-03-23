import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  collectionAddLabel,
  emptyCollectionItem,
  fieldControl,
  fieldVisible,
  findNodeType,
  normalizeOptions,
  normalizeSchema,
  propertyDescription,
  propertyLabel,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import PropertyEngineField from "./property-engine-field";

function isSelect(field) {
  return fieldControl(field) === "select";
}

function isCollection(field) {
  return field.type === "collection";
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

export default class PropertyEngineCollection extends Component {
  @tracked _activeAttrs = new Map();

  get addLabel() {
    return collectionAddLabel(this.nodeDefinition, this.args.fieldName);
  }

  get description() {
    return propertyDescription(this.nodeDefinition, this.args.fieldName);
  }

  get label() {
    return propertyLabel(this.nodeDefinition, this.args.fieldName);
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

  @action
  fieldLabel(fieldName) {
    return propertyLabel(this.nodeDefinition, fieldName);
  }

  @action
  optionLabel(fieldName, option) {
    return propertyOptionLabel(this.nodeDefinition, fieldName, option);
  }

  @action
  fieldOptions(field) {
    return normalizeOptions(field.options || []);
  }

  @action
  removeItem(removeFn, index) {
    const newMap = new Map(this._activeAttrs);
    newMap.delete(index);
    this._activeAttrs = newMap;
    removeFn(index);
  }

  @action
  isAttrActive(index, field, item) {
    return isExtraFieldShown(field, item, this._activeAttrs, index);
  }

  @action
  toggleAttr(index, field, item) {
    const active = this.isAttrActive(index, field, item);
    const newMap = new Map(this._activeAttrs);
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
    this._activeAttrs = newMap;
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
    <@form.Collection
      @name={{@fieldName}}
      @tagName="div"
      as |collection index item|
    >
      <collection.Object as |object|>
        {{#if this.hasExtraFields}}
          <div class="workflows-property-engine__collection-block">
            {{#each this.itemFields key="name" as |itemField|}}
              <PropertyEngineField
                @form={{object}}
                @formApi={{@formApi}}
                @fieldName={{itemField.name}}
                @formApiPath={{concat @fieldName "." index "." itemField.name}}
                @nodeDefinition={{this.nodeDefinition}}
                @nodeType={{@nodeType}}
                @nodeTypes={{@nodeTypes}}
                @schema={{itemField}}
              />
            {{/each}}

            {{#each this.extraItemFields key="name" as |extraField|}}
              {{#if
                (isExtraFieldShown extraField item this._activeAttrs index)
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
                      <subCollection.Object as |subObject|>
                        <div
                          class="workflows-property-engine__nested-collection-item"
                        >
                          {{#each
                            (this.nestedItemFields extraField) key="name"
                            as |subField|
                          }}
                            <PropertyEngineField
                              @form={{subObject}}
                              @formApi={{@formApi}}
                              @fieldName={{subField.name}}
                              @formApiPath={{concat
                                @fieldName
                                "."
                                index
                                "."
                                extraField.name
                                "."
                                subIndex
                                "."
                                subField.name
                              }}
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
                        </div>
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
                  <PropertyEngineField
                    @form={{object}}
                    @formApi={{@formApi}}
                    @fieldName={{extraField.name}}
                    @formApiPath={{concat
                      @fieldName
                      "."
                      index
                      "."
                      extraField.name
                    }}
                    @nodeDefinition={{this.nodeDefinition}}
                    @nodeType={{@nodeType}}
                    @nodeTypes={{@nodeTypes}}
                    @schema={{extraField}}
                  />
                {{/if}}
              {{/if}}
            {{/each}}

            <div class="workflows-property-engine__block-actions">
              <DMenu
                class="btn-flat workflows-property-engine__add-attrs-btn"
                @inline={{true}}
                @modalForwardRecipient={{true}}
              >
                <:trigger>
                  {{i18n "discourse_workflows.property_engine.add_attributes"}}
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
                          @action={{fn this.toggleAttr index extraField item}}
                          @translatedLabel={{this.fieldLabel extraField.name}}
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

              <DButton
                @action={{fn this.removeItem collection.remove index}}
                @icon="trash-can"
                class="btn-flat btn-danger btn-small"
              />
            </div>
          </div>
        {{else}}
          <div
            class="workflows-configurator__key-value-row workflows-property-engine__collection-row"
          >
            {{#each this.itemFields key="name" as |itemField|}}
              {{#if (isSelect itemField)}}
                <object.Field
                  @name={{itemField.name}}
                  @title={{this.fieldLabel itemField.name}}
                  @showTitle={{false}}
                  @type="select"
                  as |field|
                >
                  <field.Control @includeNone={{false}} as |c|>
                    {{#each (this.fieldOptions itemField) as |opt|}}
                      <c.Option @value={{opt.value}}>
                        {{this.optionLabel itemField.name opt}}
                      </c.Option>
                    {{/each}}
                  </field.Control>
                </object.Field>
              {{else}}
                <object.Field
                  @name={{itemField.name}}
                  @title={{this.fieldLabel itemField.name}}
                  @showTitle={{false}}
                  @type="input"
                  as |field|
                >
                  <field.Control
                    placeholder={{propertyLabel
                      this.nodeDefinition
                      itemField.name
                    }}
                  />
                </object.Field>
              {{/if}}
            {{/each}}

            <DButton
              @action={{fn this.removeItem collection.remove index}}
              @icon="trash-can"
              @translatedLabel={{i18n
                "discourse_workflows.property_engine.remove_item"
              }}
              class="btn-flat"
            />
          </div>
        {{/if}}
      </collection.Object>
    </@form.Collection>

    <DButton
      @action={{fn @form.addItemToCollection @fieldName this.emptyItem}}
      @icon="plus"
      @translatedLabel={{this.addLabel}}
      class="btn-default"
    />
  </template>
}
