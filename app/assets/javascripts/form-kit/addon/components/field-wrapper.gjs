import Component from "@glimmer/component";
import Row from "./row";

export default class FieldWrapper extends Component {
  <template>
    {{#if @node.context.horizontal}}
      <Row @node={{@node}}>
        {{yield}}
      </Row>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
