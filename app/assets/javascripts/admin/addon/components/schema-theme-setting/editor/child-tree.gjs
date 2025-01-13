import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import dIcon from "discourse/helpers/d-icon";
import ChildTreeNode from "admin/components/schema-theme-setting/editor/child-tree-node";

export default class SchemaThemeSettingNewEditorChildTree extends Component {
  @tracked expanded = true;

  @action
  toggleVisibility() {
    this.expanded = !this.expanded;
  }

  @action
  onChildClick(index) {
    return this.args.onChildClick(
      index,
      this.args.name,
      this.args.parentNodeIndex,
      this.args.parentNodeText
    );
  }

  <template>
    <div
      class="schema-theme-setting-editor__tree-node --heading"
      role="button"
      {{on "click" this.toggleVisibility}}
    >
      {{@name}}
      {{dIcon (if this.expanded "chevron-down" "chevron-right")}}
    </div>

    {{#if this.expanded}}
      <ul>
        {{#each @objects as |object index|}}
          <ChildTreeNode
            @index={{index}}
            @object={{object}}
            @onChildClick={{fn this.onChildClick index}}
            @schema={{@schema}}
            @generateSchemaTitle={{@generateSchemaTitle}}
            data-test-parent-index={{@parentNodeIndex}}
          />
        {{/each}}

        <li class="schema-theme-setting-editor__tree-node --child --add-button">
          <DButton
            @action={{fn @addChildItem @name @parentNodeIndex}}
            @translatedLabel={{@schema.name}}
            @icon="plus"
            class="btn-transparent schema-theme-setting-editor__tree-add-button --child"
            data-test-parent-index={{@parentNodeIndex}}
          />
        </li>
      </ul>
    {{/if}}
  </template>
}
