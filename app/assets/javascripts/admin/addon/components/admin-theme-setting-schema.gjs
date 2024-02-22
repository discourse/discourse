import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import I18n from "discourse-i18n";

class Node {
  text = null;
  index = null;
  active = false;
  trees = [];

  constructor({ text, index }) {
    this.text = text;
    this.index = index;
  }
}

class Tree {
  propertyName = null;
  nodes = [];
}

export default class AdminThemeSettingSchema extends Component {
  @tracked activeIndex = 0;
  @tracked backButtonText;
  history = [];

  get tree() {
    let schema = this.args.schema;
    let data = this.args.data;

    for (const point of this.history) {
      data = data[point.node.index][point.propertyName];
      schema = schema.properties[point.propertyName].schema;
    }

    const tree = new Tree();
    const idProperty = schema.identifier;
    const childObjectsProperties = this.findChildObjectsProperties(
      schema.properties
    );

    data.forEach((obj, index) => {
      const node = new Node({ text: obj[idProperty], index });
      if (index === this.activeIndex) {
        node.active = true;
        for (const childObjectsProperty of childObjectsProperties) {
          const subtree = new Tree();
          subtree.propertyName = childObjectsProperty.name;
          data[index][childObjectsProperty.name].forEach(
            (childObj, childIndex) => {
              subtree.nodes.push(
                new Node({
                  text: childObj[childObjectsProperty.idProperty],
                  index: childIndex,
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

  findChildObjectsProperties(properties) {
    const list = [];
    for (const [name, spec] of Object.entries(properties)) {
      if (spec.type === "objects") {
        const subIdProperty = spec.schema.identifier;
        list.push({
          name,
          idProperty: subIdProperty,
        });
      }
    }
    return list;
  }

  @action
  onClick(node) {
    this.activeIndex = node.index;
  }

  @action
  onChildClick(node, tree, parentNode) {
    this.history.push({
      propertyName: tree.propertyName,
      node: parentNode,
    });
    this.backButtonText = I18n.t("admin.customize.theme.schema.back_button", {
      name: parentNode.text,
    });
    this.activeIndex = node.index;
  }

  @action
  backButtonClick() {
    const historyPoint = this.history.pop();
    this.activeIndex = historyPoint.node.index;
    if (this.history.length > 0) {
      this.backButtonText = I18n.t("admin.customize.theme.schema.back_button", {
        name: this.history[this.history.length - 1].node.text,
      });
    } else {
      this.backButtonText = null;
    }
  }

  <template>
    <div class="schema-editor-navigation">
      {{#if this.backButtonText}}
        <DButton
          @action={{this.backButtonClick}}
          @icon="chevron-left"
          @translatedLabel={{this.backButtonText}}
          class="back-button"
        />
      {{/if}}
      <ul class="tree">
        {{#each this.tree.nodes as |node|}}
          <div class="item-container">
            <li
              role="link"
              class="parent node{{if node.active ' active'}}"
              {{on "click" (fn this.onClick node)}}
            >
              {{node.text}}
            </li>
            {{#each node.trees as |nestedTree|}}
              <ul>
                {{#each nestedTree.nodes as |childNode|}}
                  <li
                    role="link"
                    class="child node"
                    {{on
                      "click"
                      (fn this.onChildClick childNode nestedTree node)
                    }}
                  >{{childNode.text}}</li>
                {{/each}}
              </ul>
            {{/each}}
          </div>
        {{/each}}
      </ul>
    </div>
  </template>
}
