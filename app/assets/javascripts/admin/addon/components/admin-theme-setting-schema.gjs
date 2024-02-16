import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";

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

@tagName("")
export default class AdminThemeSettingSchema extends Component {
  @tracked activeIndex = 0;
  history = [];

  get tree() {
    let schema = this.args.schema;
    let data = this.args.data;

    for (const point of this.history) {
      data = data[point];
      if (typeof point === "string") {
        schema = schema.properties[point].schema;
      }
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
  onChildClick(node, tree) {
    this.history.push(this.activeIndex, tree.propertyName);
    this.activeIndex = node.index;
  }

  <template>
    <div class="schema-editor-navigation">
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
                    {{on "click" (fn this.onChildClick childNode nestedTree)}}
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
