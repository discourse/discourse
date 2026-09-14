import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { on } from "@ember/modifier";
import ChildTree from "discourse/admin/components/schema-setting/editor/child-tree";
import { bind } from "discourse/lib/decorators";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class SchemaSettingNewEditorTreeNode extends Component {
  @tracked text;

  childObjectsProperties = this.findChildObjectsProperties(
    this.args.schema.properties
  );

  constructor() {
    super(...arguments);
    this.setText();
    this.args.registerInputFieldObserver(this.args.index, this.setText);
  }

  @bind
  setText() {
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
      class={{dConcatClass
        "schema-setting-editor__tree-node --parent"
        (if @active "--active")
      }}
      role="link"
      {{on "click" @onClick}}
    >
      <div class="schema-setting-editor__tree-node-text">
        <span>{{this.text}}</span>

        {{#if (gt this.childObjectsProperties.length 0)}}
          {{dIcon (if @active "chevron-down" "chevron-right")}}
        {{else}}
          {{dIcon "chevron-right"}}
        {{/if}}
      </div>

      {{#if @active}}
        {{#each this.childObjectsProperties as |childObjectsProperty|}}
          <ChildTree
            @addChildItem={{@addChildItem}}
            @generateSchemaTitle={{@generateSchemaTitle}}
            @name={{childObjectsProperty.name}}
            @objects={{get @object childObjectsProperty.name}}
            @onChildClick={{@onChildClick}}
            @parentNodeIndex={{@index}}
            @parentNodeText={{this.text}}
            @schema={{childObjectsProperty.schema}}
          />
        {{/each}}
      {{/if}}
    </li>
  </template>
}
