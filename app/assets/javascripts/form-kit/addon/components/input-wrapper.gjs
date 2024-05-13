import Component from "@glimmer/component";
import Col from "./col";

export default class InputWrapper extends Component {
  get size() {
    return this.args.node.context.horizontal ? 10 : this.args.node.context.size;
  }

  <template>
    <Col @node={{@node}} @size={{this.size}}>
      {{yield}}
    </Col>
  </template>
}
