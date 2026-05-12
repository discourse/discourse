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
      {{on "click" @onClick}}
      role="link"
      class={{dConcatClass
        "schema-setting-editor__tree-node --parent"
        (if @active "--active")
      }}
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
