import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse-common/helpers/d-icon";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";
import FieldInput from "./field";

class Node {
  @tracked text;
  object;
  schema;
  index;
  active = false;
  parentTree;
  trees = [];

  constructor({ text, index, object, schema, parentTree }) {
    this.text = text;
    this.index = index;
    this.object = object;
    this.schema = schema;
    this.parentTree = parentTree;
  }
}

class Tree {
  @tracked nodes = [];
  data = [];
  propertyName;
  schema;
}

export default class SchemaThemeSettingEditor extends Component {
  @service router;
  @tracked activeIndex = 0;
  @tracked backButtonText;
  @tracked saveButtonDisabled = false;
  @tracked visibilityStates = [];

  data = cloneJSON(this.args.setting.value);
  history = [];
  schema = this.args.setting.objects_schema;

  @cached
  get tree() {
    let schema = this.schema;
    let data = this.data;
    let tree = new Tree();
    tree.data = data;
    tree.schema = schema;

    for (const point of this.history) {
      data = data[point.parentNode.index][point.propertyName];
      schema = schema.properties[point.propertyName].schema;

      tree.propertyName = point.propertyName;
      tree.schema = point.node.schema;
      tree.data = data;
    }

    data.forEach((object, index) => {
      const node = new Node({
        index,
        schema,
        object,
        text:
          object[schema.identifier] ||
          this.defaultSchemaIdentifier(schema.name, index),
        parentTree: tree,
      });

      if (index === this.activeIndex) {
        node.active = true;

        const childObjectsProperties = this.findChildObjectsProperties(
          schema.properties
        );

        for (const childObjectsProperty of childObjectsProperties) {
          const subtree = new Tree();
          subtree.propertyName = childObjectsProperty.name;
          subtree.schema = childObjectsProperty.schema;
          subtree.data = data[index][childObjectsProperty.name] ||= [];

          data[index][childObjectsProperty.name]?.forEach(
            (childObj, childIndex) => {
              subtree.nodes.push(
                new Node({
                  text:
                    childObj[childObjectsProperty.schema.identifier] ||
                    `${childObjectsProperty.schema.name} ${childIndex + 1}`,
                  index: childIndex,
                  object: childObj,
                  schema: childObjectsProperty.schema,
                  parentTree: subtree,
                })
              );
            }
          );

          node.trees.push(subtree);
        }
      }

      tree.nodes.push(node);
    });

    return tree;
  }

  @cached
  get activeNode() {
    return this.tree.nodes.find((node, index) => {
      return index === this.activeIndex;
    });
  }

  get fields() {
    const node = this.activeNode;
    const list = [];

    if (!node) {
      return list;
    }

    for (const [name, spec] of Object.entries(node.schema.properties)) {
      if (spec.type === "objects") {
        continue;
      }

      list.push({
        name,
        spec,
        value: node.object[name],
        description: this.fieldDescription(name),
      });
    }

    return list;
  }

  findChildObjectsProperties(properties) {
    const list = [];

    for (const [name, spec] of Object.entries(properties)) {
      if (spec.type === "objects") {
        list.push({
          name,
          schema: spec.schema,
        });
      }
    }

    return list;
  }

  @action
  saveChanges() {
    this.saveButtonDisabled = true;

    this.args.setting
      .updateSetting(this.args.themeId, this.data)
      .then((result) => {
        this.args.setting.set("value", result[this.args.setting.setting]);

        this.router.transitionTo(
          "adminCustomizeThemes.show",
          this.args.themeId
        );
      })
      .catch(popupAjaxError)
      .finally(() => (this.saveButtonDisabled = false));
  }

  @action
  onClick(node) {
    this.activeIndex = node.index;
  }

  @action
  onChildClick(node, tree, parentNode) {
    this.history.push({
      propertyName: tree.propertyName,
      parentNode,
      node,
    });

    this.backButtonText = I18n.t("admin.customize.theme.schema.back_button", {
      name: parentNode.text,
    });

    this.activeIndex = node.index;
  }

  @action
  backButtonClick() {
    const historyPoint = this.history.pop();
    this.activeIndex = historyPoint.parentNode.index;

    if (this.history.length > 0) {
      this.backButtonText = I18n.t("admin.customize.theme.schema.back_button", {
        name: this.history[this.history.length - 1].parentNode.text,
      });
    } else {
      this.backButtonText = null;
    }
  }

  @action
  inputFieldChanged(field, newVal) {
    if (field.name === this.activeNode.schema.identifier) {
      this.activeNode.text = newVal;
    }

    this.activeNode.object[field.name] = newVal;
  }

  @action
  addItem(tree) {
    const schema = tree.schema;
    const node = this.createNodeFromSchema(schema, tree);
    tree.data.push(node.object);
    tree.nodes = [...tree.nodes, node];
  }

  @action
  removeItem() {
    const data = this.activeNode.parentTree.data;
    data.splice(this.activeIndex, 1);
    this.tree.nodes = this.tree.nodes.filter((n, i) => i !== this.activeIndex);

    if (data.length > 0) {
      this.activeIndex = Math.max(this.activeIndex - 1, 0);
    } else if (this.history.length > 0) {
      this.backButtonClick();
    }
  }

  @action
  toggleListVisibility(listIdentifier) {
    if (this.visibilityStates.includes(listIdentifier)) {
      this.visibilityStates = this.visibilityStates.filter(
        (id) => id !== listIdentifier
      );
    } else {
      this.visibilityStates = [...this.visibilityStates, listIdentifier];
    }
  }

  get isListVisible() {
    return (listIdentifier) => {
      return this.visibilityStates.includes(listIdentifier);
    };
  }

  fieldDescription(fieldName) {
    const descriptions = this.args.setting.metadata?.property_descriptions;

    if (!descriptions) {
      return;
    }

    let key;

    if (this.activeNode.parentTree.propertyName) {
      key = `${this.activeNode.parentTree.propertyName}.${fieldName}`;
    } else {
      key = `${fieldName}`;
    }

    return descriptions[key];
  }

  defaultSchemaIdentifier(schemaName, index) {
    return `${schemaName} ${index + 1}`;
  }

  createNodeFromSchema(schema, tree) {
    const object = {};
    const index = tree.nodes.length;
    const defaultName = this.defaultSchemaIdentifier(schema.name, index);

    if (schema.identifier) {
      object[schema.identifier] = defaultName;
    }

    for (const [name, spec] of Object.entries(schema.properties)) {
      if (spec.type === "objects") {
        object[name] = [];
      }
    }

    return new Node({
      schema,
      object,
      index,
      text: defaultName,
      parentTree: tree,
    });
  }

  uniqueNodeId(nestedTreePropertyName, nodeIndex) {
    return `${nestedTreePropertyName}-${nodeIndex}`;
  }

  <template>
    {{! template-lint-disable no-nested-interactive }}
    <div class="schema-theme-setting-editor">
      <div class="schema-theme-setting-editor__navigation">
        <ul class="schema-theme-setting-editor__tree">
          {{#if this.backButtonText}}
            <li
              role="link"
              class="schema-theme-setting-editor__tree-node --back-btn"
              {{on "click" this.backButtonClick}}
            >
              <div class="schema-theme-setting-editor__tree-node-text">
                {{dIcon "arrow-left"}}
                {{this.backButtonText}}
              </div>
            </li>
          {{/if}}

          {{#each this.tree.nodes as |node|}}
            <li
              role="link"
              class="schema-theme-setting-editor__tree-node --parent
                {{if node.active ' --active'}}"
              {{on "click" (fn this.onClick node)}}
            >
              <div class="schema-theme-setting-editor__tree-node-text">
                <span>{{node.text}}</span>
                {{#if node.parentTree.propertyName}}
                  {{dIcon "chevron-right"}}
                {{else}}
                  {{dIcon (if node.active "chevron-down" "chevron-right")}}
                {{/if}}
              </div>

              {{#each node.trees as |nestedTree|}}
                <div
                  class="schema-theme-setting-editor__tree-node --heading"
                  {{on
                    "click"
                    (fn
                      this.toggleListVisibility
                      (this.uniqueNodeId nestedTree.propertyName node.index)
                    )
                  }}
                >
                  {{nestedTree.propertyName}}
                  {{dIcon
                    (if
                      (this.isListVisible
                        (this.uniqueNodeId nestedTree.propertyName node.index)
                      )
                      "chevron-right"
                      "chevron-down"
                    )
                  }}
                </div>
                <ul
                  class="{{if
                      (this.isListVisible
                        (this.uniqueNodeId nestedTree.propertyName node.index)
                      )
                      '--is-hidden'
                      '--is-visible'
                    }}"
                >
                  {{#each nestedTree.nodes as |childNode|}}
                    <li
                      role="link"
                      class="schema-theme-setting-editor__tree-node --child"
                      {{on
                        "click"
                        (fn this.onChildClick childNode nestedTree node)
                      }}
                      data-test-parent-index={{node.index}}
                    >
                      <div class="schema-theme-setting-editor__tree-node-text">
                        <span>{{childNode.text}}</span>
                        {{dIcon "chevron-right"}}
                      </div>
                    </li>
                  {{/each}}
                  <li
                    class="schema-theme-setting-editor__tree-node --child --add-button"
                  >
                    <DButton
                      @action={{fn this.addItem nestedTree}}
                      @translatedLabel={{nestedTree.schema.name}}
                      @icon="plus"
                      class="btn-transparent schema-theme-setting-editor__tree-add-button --child"
                      data-test-parent-index={{node.index}}
                    />
                  </li>
                </ul>
              {{/each}}
            </li>
          {{/each}}

          <li
            class="schema-theme-setting-editor__tree-node --parent --add-button"
          >
            <DButton
              @action={{fn this.addItem this.tree}}
              @translatedLabel={{this.tree.schema.name}}
              @icon="plus"
              class="btn-transparent schema-theme-setting-editor__tree-add-button --root"
            />
          </li>
        </ul>

        <div class="schema-theme-setting-editor__footer">
          <DButton
            @disabled={{this.saveButtonDisabled}}
            @action={{this.saveChanges}}
            @label="save"
            class="btn-primary"
          />
        </div>
      </div>

      <div class="schema-theme-setting-editor__fields">
        {{#each this.fields as |field|}}
          <FieldInput
            @name={{field.name}}
            @value={{field.value}}
            @spec={{field.spec}}
            @onValueChange={{fn this.inputFieldChanged field}}
            @description={{field.description}}
          />
        {{/each}}
        {{#if (gt this.fields.length 0)}}
          <DButton
            @action={{this.removeItem}}
            @icon="trash-alt"
            class="btn-danger schema-theme-setting-editor__remove-btn"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
