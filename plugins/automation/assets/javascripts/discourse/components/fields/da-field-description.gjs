import Component from "@glimmer/component";

export default class FieldDescription extends Component {
  <template>
    {{#if @description}}
      <p class="control-description">
        {{@description}}
      </p>
    {{/if}}
  </template>
}
