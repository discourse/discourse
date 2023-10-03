import Component from "@glimmer/component";

export default class FieldLabel extends Component {
  <template>
    {{#if @label}}
      <label class="control-label">
        <span>
          {{@label}}
          {{#if @field.isRequired}}
            *
          {{/if}}
        </span>
      </label>
    {{/if}}
  </template>
}
