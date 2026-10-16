import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { on } from "@ember/modifier";
import ChildTree from "discourse/admin/components/schema-setting/editor/child-tree";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class SchemaSettingNewEditorTreeNode extends Component {
  get childObjectsProperties() {
    return Object.entries(this.args.schema.properties)
      .filter(([, spec]) => spec.type === "objects")
      .map(([name, spec]) => ({ name, schema: spec.schema }));
  }

  get text() {
    return this.args.generateSchemaTitle(
      this.args.object,
      this.args.schema,
      this.args.index
    );
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
