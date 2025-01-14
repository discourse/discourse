import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { gt } from "truth-helpers";
import dIcon from "discourse/helpers/d-icon";
import ChildTree from "admin/components/schema-theme-setting/editor/child-tree";

export default class SchemaThemeSettingNewEditorTreeNode extends Component {
  @tracked text;

  childObjectsProperties = this.findChildObjectsProperties(
    this.args.schema.properties
  );

  constructor() {
    super(...arguments);
    this.#setText();
  }

  @action
  registerInputFieldObserver() {
    this.args.registerInputFieldObserver(
      this.args.index,
      this.#setText.bind(this)
    );
  }

  #setText() {
    this.text = this.args.generateSchemaTitle(
      this.args.object,
      this.args.schema,
      this.args.index
    );
  }

  findChildObjectsProperties(properties) {
    const list = [];

    for (const [name, spec] of Object.entries(properties)) {
      if (spec.type === "objects") {
        this.args.object[name] ||= [];

        list.push({
          name,
          schema: spec.schema,
        });
      }
    }

    return list;
  }

  <template>
    <li
      role="link"
      class="schema-theme-setting-editor__tree-node --parent
        {{if @active ' --active'}}"
      {{on "click" (fn @onClick @index)}}
    >
      <div class="schema-theme-setting-editor__tree-node-text">
        <span {{didInsert this.registerInputFieldObserver}}>{{this.text}}</span>

        {{#if (gt this.childObjectsProperties.length 0)}}

          {{dIcon (if @active "chevron-down" "chevron-right")}}
        {{else}}
          {{dIcon "chevron-right"}}
        {{/if}}
      </div>

      {{#if @active}}
        {{#each this.childObjectsProperties as |childObjectsProperty|}}
          <ChildTree
            @name={{childObjectsProperty.name}}
            @schema={{childObjectsProperty.schema}}
            @objects={{get @object childObjectsProperty.name}}
            @parentNodeText={{this.text}}
            @parentNodeIndex={{@index}}
            @onChildClick={{@onChildClick}}
            @addChildItem={{@addChildItem}}
            @generateSchemaTitle={{@generateSchemaTitle}}
          />
        {{/each}}
      {{/if}}
    </li>
  </template>
}
