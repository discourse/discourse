import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { and, not } from "discourse/truth-helpers";

export default class SchemaField extends Component {
  @tracked collapsed = true;

  get hasChildren() {
    return this.args.field.children?.length > 0;
  }

  @action
  toggleChildren(event) {
    event.preventDefault();
    this.collapsed = !this.collapsed;
  }

  get fieldId() {
    const { field, parentPath } = this.args;
    return parentPath ? `${parentPath}.${field.id}` : field.id;
  }

  @action
  handleDragStart(event) {
    event.stopPropagation();
    const field = this.args.field;
    event.dataTransfer.setData(
      "application/x-workflow-variable",
      JSON.stringify({ id: this.fieldId, key: field.key, type: field.type })
    );
    event.dataTransfer.effectAllowed = "copy";
  }

  <template>
    <li
      class="workflows-schema-field
        {{if this.hasChildren '--has-children'}}
        {{if this.collapsed '--collapsed'}}"
      draggable={{if (and @draggable this.fieldId (not this.hasChildren)) "true"}}
      {{on "dragstart" this.handleDragStart}}
    >
      <div
        class="workflows-schema-field__row"
        {{(if this.hasChildren (modifier on "click" this.toggleChildren))}}
      >
        {{#if this.hasChildren}}
          <span class="workflows-schema-field__toggle">
            {{icon (if this.collapsed "angle-right" "angle-down")}}
          </span>
        {{/if}}
        <span class="workflows-schema-field__key">{{@field.key}}</span>
        <span class="workflows-schema-field__type" data-type={{@field.type}}>
          {{@field.type}}
        </span>
      </div>

      {{#if (and this.hasChildren (not this.collapsed))}}
        <ul class="workflows-schema-field-list --nested">
          {{#each @field.children as |child|}}
            <SchemaField
              @field={{child}}
              @draggable={{@draggable}}
              @parentPath={{this.fieldId}}
            />
          {{/each}}
        </ul>
      {{/if}}
    </li>
  </template>
}
