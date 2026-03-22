import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and } from "discourse/truth-helpers";

export default class SchemaField extends Component {
  @action
  handleDragStart(event) {
    const field = this.args.field;
    event.dataTransfer.setData(
      "application/x-workflow-variable",
      JSON.stringify({ id: field.id, key: field.key, type: field.type })
    );
    event.dataTransfer.effectAllowed = "copy";
  }

  <template>
    <li
      class="workflows-schema-field"
      draggable={{if (and @draggable @field.id) "true"}}
      {{on "dragstart" this.handleDragStart}}
    >
      <span class="workflows-schema-field__key">{{@field.key}}</span>
      <span class="workflows-schema-field__type" data-type={{@field.type}}>
        {{@field.type}}
      </span>
    </li>
  </template>
}
